#!/usr/bin/env python3
"""
Simple fulfillment worker:
- Scans workspace/state/proposals for JSON files
- If a proposal has "approved": true and not "fulfilled": true, mark fulfilled and run post-fulfillment action
- Post-fulfillment action: call ./telegram_send.sh "Proposal X fulfilled: <link>" (script should handle sending)
- Idempotent and safe to run periodically (cron or supervisor)
"""
import json
import os
import subprocess
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
PROPOSALS_DIR = BASE / 'state' / 'proposals'
LOG = BASE / 'logs' / 'fulfillment.log'
TELEGRAM_SCRIPT = BASE / 'scripts' / 'telegram_send.sh'


def log(msg):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, 'a') as f:
        f.write(msg + "\n")
    print(msg)


def send_telegram(message):
    if TELEGRAM_SCRIPT.exists() and os.access(TELEGRAM_SCRIPT, os.X_OK):
        try:
            subprocess.run([str(TELEGRAM_SCRIPT), message], check=True)
            return True
        except subprocess.CalledProcessError as e:
            log(f"telegram_send failed: {e}")
            return False
    else:
        log("telegram_send script missing or not executable; skipping send")
        return False


def process_proposal(path: Path):
    try:
        with open(path, 'r+') as f:
            data = json.load(f)
            if data.get('fulfilled'):
                return
            if data.get('approved'):
                # mark fulfilled
                data['fulfilled'] = True
                data['fulfilled_at'] = subprocess.check_output(['date','-u']).decode().strip()
                f.seek(0)
                json.dump(data, f, indent=2)
                f.truncate()
                msg = f"Proposal {data.get('id', path.stem)} fulfilled"
                log(msg)
                sent = send_telegram(msg + ": your download is ready")
                if not sent:
                    log("Warning: telegram delivery failed; fulfillment still recorded")
    except Exception as e:
        log(f"error processing {path}: {e}")


def main():
    PROPOSALS_DIR.mkdir(parents=True, exist_ok=True)
    for p in sorted(PROPOSALS_DIR.glob('proposal-*.json')):
        process_proposal(p)

if __name__ == '__main__':
    main()
