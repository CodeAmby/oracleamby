#!/usr/bin/env python3
import time, subprocess, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
STATE=ROOT/'state'
LOG=ROOT/'logs'
LOG.mkdir(parents=True,exist_ok=True)
STATE.mkdir(parents=True,exist_ok=True)
ADDR_FILE=STATE/'amby_btc_address.txt'

# read address from file (created below) or abort
if not ADDR_FILE.exists():
    print('No BTC address file found at', ADDR_FILE)
    raise SystemExit(1)
addr = open(ADDR_FILE).read().strip()

print('Watching BTC address', addr)

while True:
    # simple balance check via Blockcypher or Blockchair
    try:
        import requests
        r = requests.get(f'https://api.blockchair.com/bitcoin/dashboards/address/{addr}')
        data = r.json()
        balance = data['data'][addr]['address']['balance']
        # balance satoshis
        if balance>0:
            print('Incoming balance sat:', balance)
            # send telegram notification
            SCRIPT=str(ROOT/'scripts'/'telegram_send.sh')
            if Path(SCRIPT).exists():
                subprocess.call([SCRIPT, f"[Amby] BTC address {addr} balance sat: {balance}"])
        else:
            print('balance 0')
    except Exception as e:
        print('err',e)
    time.sleep(60)
