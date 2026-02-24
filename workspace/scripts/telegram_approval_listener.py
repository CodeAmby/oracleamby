#!/usr/bin/env python3
import os,sys,time,subprocess,json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
STATE_DIR=ROOT/ 'state'
PROPOSAL_DIR=STATE_DIR/ 'proposals'
LOG_DIR=ROOT/ 'logs'
LOG_FILE=LOG_DIR/ 'approvals.log'

# read secrets from Keychain
def keychain_read(service, account='amby'):
    try:
        out = subprocess.check_output(['security','find-generic-password','-s',service,'-a',account,'-w'])
        return out.decode().strip()
    except subprocess.CalledProcessError:
        return None

BOT_TOKEN = keychain_read('TELEGRAM_BOT_TOKEN')
CONTROLLER_CHAT = keychain_read('CONTROLLER_CHAT_ID')
if CONTROLLER_CHAT is not None and CONTROLLER_CHAT.startswith('telegram:'):
    CONTROLLER_CHAT = CONTROLLER_CHAT.split(':',1)[1]

if not BOT_TOKEN or not CONTROLLER_CHAT:
    print('Missing TELEGRAM_BOT_TOKEN or CONTROLLER_CHAT_ID in Keychain. Exiting.')
    sys.exit(1)

API_BASE = f'https://api.telegram.org/bot{BOT_TOKEN}'

def log(msg):
    t = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    s = f"{t} {msg}\n"
    Path(LOG_DIR).mkdir(parents=True,exist_ok=True)
    with open(LOG_FILE,'a') as f:
        f.write(s)
    print(s,end='')

# read proposal
def load_proposal(pid):
    p = PROPOSAL_DIR/ f'proposal-{pid}.json'
    if not p.exists():
        return None
    return json.load(open(p,'r',encoding='utf-8'))

def write_proposal(pid, data):
    p = PROPOSAL_DIR/ f'proposal-{pid}.json'
    json.dump(data, open(p,'w',encoding='utf-8'), indent=2)

# send telegram message
def send_msg(text):
    import requests
    resp = requests.post(f"{API_BASE}/sendMessage", json={
        'chat_id': int(CONTROLLER_CHAT), 'text': text
    })
    return resp.json()

# process an approval command
def handle_approve(pid, user_id):
    if str(user_id) != str(CONTROLLER_CHAT):
        send_msg("Unauthorized: only controller can approve proposals.")
        return
    prop = load_proposal(pid)
    if not prop:
        send_msg(f"Proposal {pid} not found.")
        return
    status = prop.get('status','pending')
    if status!='pending':
        send_msg(f"Proposal {pid} status is {status}, cannot approve.")
        return
    # mark as awaiting_confirm
    prop['status']='awaiting_confirm'
    write_proposal(pid, prop)
    send_msg(f"Approve received for {pid}. Please confirm by replying: confirm {pid}")
    log(f"approve requested by {user_id} for {pid}")

def handle_confirm(pid, user_id):
    if str(user_id) != str(CONTROLLER_CHAT):
        send_msg("Unauthorized: only controller can confirm proposals.")
        return
    prop = load_proposal(pid)
    if not prop:
        send_msg(f"Proposal {pid} not found.")
        return
    if prop.get('status')!='awaiting_confirm':
        send_msg(f"Proposal {pid} is not awaiting confirm (status={prop.get('status')}).")
        return
    # broadcast via eth_action.sh
    to = prop['to']
    value = prop['value_wei']
    log(f"Broadcasting proposal {pid} to {to} value_wei {value}")
    # call eth_action.sh with broadcast
    eth_action = str(ROOT/ 'scripts' / 'eth_action.sh')
    try:
        out = subprocess.check_output([eth_action, to, str(value), '--broadcast'], stderr=subprocess.STDOUT, text=True)
        # try to find txhash in output
        txhash = None
        for line in out.splitlines():
            if line.startswith('txhash='):
                txhash=line.split('=',1)[1].strip()
        prop['status']='broadcasted' if txhash else 'failed'
        prop['txhash']=txhash
        write_proposal(pid, prop)
        if txhash:
            send_msg(f"Proposal {pid} broadcasted. tx: {txhash}")
            log(f"proposal {pid} broadcasted tx {txhash}")
        else:
            send_msg(f"Proposal {pid} broadcast attempt failed. See logs.")
            log(f"proposal {pid} broadcast failed: {out}")
    except subprocess.CalledProcessError as e:
        send_msg(f"Broadcast failed for {pid}: {e.output}")
        prop['status']='failed'
        write_proposal(pid, prop)
        log(f"broadcast error for {pid}: {e.output}")

def handle_deny(pid, user_id):
    if str(user_id) != str(CONTROLLER_CHAT):
        send_msg("Unauthorized: only controller can deny proposals.")
        return
    prop = load_proposal(pid)
    if not prop:
        send_msg(f"Proposal {pid} not found.")
        return
    prop['status']='denied'
    write_proposal(pid, prop)
    send_msg(f"Proposal {pid} denied.")
    log(f"proposal {pid} denied by {user_id}")

# polling loop for updates (durable, idempotent)
last_update_file = STATE_DIR / 'telegram_last_update_id'
processed_file = STATE_DIR / 'telegram_processed_ids.json'
# load persisted last_update_id
try:
    last_update_id = int(open(last_update_file,'r').read().strip())
except Exception:
    last_update_id = 0
# load processed update ids set
try:
    processed = set(json.load(open(processed_file,'r')))
except Exception:
    processed = set()

import requests
backoff=1
help_throttle = {}  # chat_id -> last_sent_time
HELP_COOLDOWN=60
while True:
    try:
        resp = requests.get(f"{API_BASE}/getUpdates", params={'offset': last_update_id+1, 'timeout': 20})
        data = resp.json()
        if not data.get('ok'):
            time.sleep(2)
            continue
        results = data.get('result', [])
        for u in results:
            uid = u.get('update_id')
            if str(uid) in processed:
                # already handled
                last_update_id = max(last_update_id, uid)
                continue
            # mark as processed early to avoid reprocessing on crash
            processed.add(str(uid))
            with open(processed_file,'w') as f:
                json.dump(list(processed), f)
            last_update_id = max(last_update_id, uid)
            # persist last_update_id
            open(last_update_file,'w').write(str(last_update_id))

            msg = u.get('message') or u.get('edited_message')
            if not msg: continue
            chat = msg.get('chat',{})
            user_id = chat.get('id')
            # only process text messages
            text = msg.get('text')
            if not text:
                # ignore non-text
                continue
            text = text.strip()
            parts = text.split()
            cmd = parts[0].lower()
            if cmd=='approve' and len(parts)>=2:
                pid = parts[1]
                handle_approve(pid, user_id)
            elif cmd=='confirm' and len(parts)>=2:
                pid = parts[1]
                handle_confirm(pid, user_id)
            elif cmd=='deny' and len(parts)>=2:
                pid = parts[1]
                handle_deny(pid, user_id)
            elif cmd=='status' and len(parts)>=2:
                pid = parts[1]
                prop = load_proposal(pid)
                send_msg(json.dumps(prop, indent=2) if prop else f'Proposal {pid} not found')
            else:
                # throttle help messages to once per minute per user
                now = time.time()
                last = help_throttle.get(str(user_id), 0)
                if now - last > HELP_COOLDOWN and str(user_id)==str(CONTROLLER_CHAT):
                    send_msg("Commands: approve <id>, confirm <id>, deny <id>, status <id>")
                    help_throttle[str(user_id)] = now
        backoff=1
    except Exception as e:
        log(f"listener error: {e}")
        time.sleep(backoff)
        backoff = min(backoff*2, 60)
