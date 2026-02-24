#!/bin/bash
# Get the latest Nouns DAO proposal ID (proposal count)
# Usage: ./latest-proposal.sh

set -euo pipefail

RPC_URL="https://eth.llamarpc.com"
DAO="0x6f3E6272A167e8AcCb32072d08E0957F9c79223d"

RESULT=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"'"$DAO"'","data":"0xda35c664"},"latest"],"id":1}' | jq -r '.result')

if [ "$RESULT" = "null" ] || [ -z "$RESULT" ]; then
  echo "Error: Failed to fetch proposal count" >&2
  exit 1
fi

COUNT=$((16#${RESULT: -8}))
echo "Latest Proposal ID: $COUNT"
echo "View at: https://nouns.wtf/vote/$COUNT"
