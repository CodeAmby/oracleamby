#!/usr/bin/env python3
import time, json
from web3 import Web3

import subprocess, os
alchemy_key = None
try:
    alchemy_key = subprocess.check_output(['security','find-generic-password','-s','ALCHEMY_API_KEY','-a','amby','-w']).decode().strip()
except Exception:
    alchemy_key = None
if alchemy_key:
    RPC = f'https://eth-sepolia.g.alchemy.com/v2/{alchemy_key}'
else:
    RPC = 'https://rpc.sepolia.org'
w3=Web3(Web3.HTTPProvider(RPC))
agent_address=''
# read agent address from AMBY_ETH_HOT
import subprocess
try:
    priv = subprocess.check_output(['security','find-generic-password','-s','AMBY_ETH_HOT','-a','amby','-w']).decode().strip()
    from eth_account import Account
    acct = Account.from_key(bytes.fromhex(priv if not priv.startswith('0x') else priv[2:]))
    agent_address = acct.address
except Exception as e:
    print('Could not read agent key from Keychain:',e)
    raise

print('Watching address', agent_address)

import subprocess

def notify(text):
    # call telegram_send if available
    script = os.path.join(os.path.dirname(__file__), 'telegram_send.sh')
    if os.path.exists(script):
        subprocess.call([script, text])
    else:
        print('telegram_send not found;', text)

# naive poll
seen=set()
while True:
    try:
        latest = w3.eth.get_block('latest').transactions
        for t in latest:
            tx = w3.eth.get_transaction(t)
            if tx['to'] and tx['to'].lower()==agent_address.lower() and tx['hash'].hex() not in seen:
                seen.add(tx['hash'].hex())
                msg = json.dumps({'event':'incoming','tx_hash':tx['hash'].hex(),'from':tx['from'],'value':str(tx['value'])})
                print(msg)
                notify(f"[Amby] Incoming tx to agent: from {tx['from']} value wei {tx['value']} tx {tx['hash'].hex()}")
    except Exception as e:
        print('err',e)
    time.sleep(15)
