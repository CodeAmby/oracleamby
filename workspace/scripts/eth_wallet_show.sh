#!/usr/bin/env bash
set -euo pipefail

KEY=$(security find-generic-password -s AMBY_ETH_HOT -a amby -w 2>/dev/null || true)
if [ -z "$KEY" ]; then
  echo "No AMBY_ETH_HOT key found in Keychain."
  exit 1
fi
python3 - <<PY
from eth_account import Account
priv = "$KEY"
acct = Account.from_key(bytes.fromhex(priv if priv.startswith('0x')==False else priv[2:]))
print(acct.address)
PY
