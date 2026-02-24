#!/usr/bin/env python3
import time, json
from web3 import Web3

RPC='https://rpc.sepolia.org'
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

def handle_tx(tx):
    print('tx',tx)

# naive poll
seen=set()
while True:
    try:
        latest = w3.eth.get_block('latest').transactions
        for t in latest:
            tx = w3.eth.get_transaction(t)
            if tx['to'] and tx['to'].lower()==agent_address.lower() and tx['hash'].hex() not in seen:
                seen.add(tx['hash'].hex())
                print(json.dumps({'event':'incoming','tx':tx}, default=str))
    except Exception as e:
        print('err',e)
    time.sleep(15)
