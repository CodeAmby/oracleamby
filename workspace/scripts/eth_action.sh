#!/usr/bin/env bash
set -euo pipefail
# eth_action: sign and optionally broadcast a raw tx using AMBY_ETH_HOT key from Keychain
# Usage: eth_action.sh <to_address> <value_wei> [--broadcast]

TO=${1}
VALUE=${2}
BROADCAST=${3:-}

# Thresholds (USD) - enforced defaults configured earlier
PER_TX_USD_THRESHOLD=20
DAILY_USD_LIMIT=100

KEY=$(security find-generic-password -s AMBY_ETH_HOT -a amby -w 2>/dev/null || true)
if [ -z "$KEY" ]; then
  echo "No AMBY_ETH_HOT key found in Keychain."
  exit 1
fi

# helper: convert wei to USD using Coingecko
get_eth_usd() {
  python3 - <<PY
import sys,requests
r = requests.get('https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd', timeout=10).json()
print(r.get('ethereum',{}).get('usd',0))
PY
}

ETH_USD=$(get_eth_usd)
if [ -z "$ETH_USD" ] || [ "$ETH_USD" = "0" ]; then
  echo "Warning: could not fetch ETH price; aborting to be safe."
  exit 1
fi

# compute value in USD
# VALUE input expected to be in wei
VALUE_ETH=$(python3 - <<PY
from decimal import Decimal
wei = Decimal($VALUE)
print(wei/Decimal(10**18))
PY
)
VALUE_USD=$(python3 - <<PY
from decimal import Decimal
eth = Decimal('$VALUE_ETH')
price = Decimal('$ETH_USD')
print((eth*price).quantize(Decimal('0.01')))
PY
)

# check daily usage
STATE_DIR="$(cd "$(dirname "$0")/.." && pwd)/state"
mkdir -p "$STATE_DIR"
DAILY_FILE="$STATE_DIR/daily_spend.json"
if [ ! -f "$DAILY_FILE" ]; then echo '{"date":"","spent":0}' > "$DAILY_FILE"; fi

TODAY=$(date -u +%F)
SPENT=$(python3 - <<PY
import json,sys
f='$DAILY_FILE'
try:
  j=json.load(open(f))
except:
  j={'date':'','spent':0}
if j.get('date')!= '$TODAY':
  print(0)
else:
  print(j.get('spent',0))
PY
)

NEW_SPENT=$(python3 - <<PY
from decimal import Decimal
prev=Decimal('$SPENT')
add=Decimal('$VALUE_USD')
print((prev+add).quantize(Decimal('0.01')))
PY
)

# enforce thresholds
USD_PER_TX=$(python3 - <<PY
from decimal import Decimal
print(Decimal('$VALUE_USD'))
PY
)

if (( $(python3 - <<PY
from decimal import Decimal
print(1 if Decimal('$VALUE_USD') > Decimal('$PER_TX_USD_THRESHOLD') else 0)
PY
) )); then
  echo "Transaction value $VALUE_USD USD exceeds per-tx threshold of $PER_TX_USD_THRESHOLD USD. Creating proposal instead of auto-broadcast."
  # write proposal file
  PROPOSAL_DIR="$(cd "$(dirname "$0")/.." && pwd)/state/proposals"
  mkdir -p "$PROPOSAL_DIR"
  ID=$(date +%s)
  echo "{\"id\":\"$ID\",\"to\":\"$TO\",\"value_wei\":\"$VALUE\",\"value_usd\":\"$VALUE_USD\"}" > "$PROPOSAL_DIR/proposal-$ID.json"
  # notify controller via Telegram
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  if [ -x "$ROOT/scripts/telegram_send.sh" ]; then
    "$ROOT/scripts/telegram_send.sh" "[Amby] Proposal $ID: tx to $TO for $VALUE_USD USD requires approval. Reply 'approve $ID' to broadcast."
  fi
  exit 0
fi

if (( $(python3 - <<PY
from decimal import Decimal
print(1 if Decimal('$NEW_SPENT') > Decimal('$DAILY_USD_LIMIT') else 0)
PY
) )); then
  echo "Daily spend would exceed limit ($DAILY_USD_LIMIT USD). Creating proposal."
  PROPOSAL_DIR="$(cd "$(dirname "$0")/.." && pwd)/state/proposals"
  mkdir -p "$PROPOSAL_DIR"
  ID=$(date +%s)
  echo "{\"id\":\"$ID\",\"to\":\"$TO\",\"value_wei\":\"$VALUE\",\"value_usd\":\"$VALUE_USD\"}" > "$PROPOSAL_DIR/proposal-$ID.json"
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  if [ -x "$ROOT/scripts/telegram_send.sh" ]; then
    "$ROOT/scripts/telegram_send.sh" "[Amby] Proposal $ID: tx to $TO for $VALUE_USD USD would exceed daily limit. Reply 'approve $ID' to broadcast."
  fi
  exit 0
fi

# Otherwise sign and possibly broadcast
python3 - <<PY
from web3 import Web3
from eth_account import Account
import json,sys,subprocess
import os
alchemy_key = None
try:
    import subprocess
    alchemy_key = subprocess.check_output(['security','find-generic-password','-s','ALCHEMY_API_KEY','-a','amby','-w']).decode().strip()
except Exception:
    alchemy_key = None
if alchemy_key:
    rpc = f'https://eth-sepolia.g.alchemy.com/v2/{alchemy_key}'
else:
    rpc = 'https://rpc.sepolia.org'
w3 = Web3(Web3.HTTPProvider(rpc))
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
    # update daily spend file
    f='$DAILY_FILE'
    try:
      j=json.load(open(f))
    except:
      j={'date':'','spent':0}
    import datetime
    if j.get('date')!= '$TODAY':
      j={'date':'$TODAY','spent':0}
    # add
    from decimal import Decimal
    prev=Decimal(str(j.get('spent',0)))
    add=Decimal(str($VALUE_USD))
    j['spent']=str((prev+add))
    json.dump(j,open(f,'w'))
PY
