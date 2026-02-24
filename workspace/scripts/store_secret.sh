#!/usr/bin/env bash
set -euo pipefail

# Usage: ./store_secret.sh <SERVICE_NAME> <ACCOUNT> <SECRET>
# Example: ./store_secret.sh STRIPE_SECRET felix sk_test_...

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <SERVICE_NAME> <ACCOUNT> <SECRET>"
  exit 2
fi

SERVICE="$1"
ACCOUNT="$2"
SECRET="$3"

# Delete existing entry if present
security delete-generic-password -s "$SERVICE" -a "$ACCOUNT" 2>/dev/null || true

security add-generic-password -s "$SERVICE" -a "$ACCOUNT" -w "$SECRET"

echo "Stored secret for service '$SERVICE' account '$ACCOUNT' in macOS Keychain."
exit 0
