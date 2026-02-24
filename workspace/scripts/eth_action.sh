#!/usr/bin/env bash
set -euo pipefail
# eth_action: sign and optionally broadcast a raw tx using AMBY_ETH_HOT key from Keychain
# Usage: eth_action.sh <to_address> <value_wei> [--broadcast]

TO=${1}
VALUE=${2}
BROADCAST=${3:-}
KEY=$(security find-generic-password -s AMBY_ETH_HOT -a amby -w 2>/dev/null || true)
if [ -z "$KEY" ]; then
  echo "No AMBY_ETH_HOT key found in Keychain."
  exit 1
fi
python3 - <<PY
from web3 import Web3
from eth_account import Account
import json,sys
w3 = Web3(Web3.HTTPProvider('https://rpc.sepolia.org'))
priv = "$KEY"
acct = Account.from_key(bytes.fromhex(priv if not priv.startswith('0x') else priv[2:]))
nonce = w3.eth.get_transaction_count(acct.address)
tx = {
  'to': "$TO",
  'value': int($VALUE),
  'gas': 21000,
  'gasPrice': w3.to_wei('50','gwei'),
  'nonce': nonce,
  'chainId': 11155111
}
signed = acct.sign_transaction(tx)
raw = signed.rawTransaction.hex()
print(raw)
if "$BROADCAST":
    txhash = w3.eth.send_raw_transaction(signed.rawTransaction)
    print('txhash='+txhash.hex())
PY
