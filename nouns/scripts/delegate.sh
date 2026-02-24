#!/bin/bash
# Delegate Nouns voting power to an address
# Usage: ./delegate.sh <delegatee_address>
# Example: ./delegate.sh 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5
#
# Delegate to yourself to activate your own voting power.
# Delegation transfers ALL voting power to the delegatee.

set -euo pipefail

DELEGATEE="${1:?Usage: delegate.sh <delegatee_address>}"

if ! command -v bankr >/dev/null 2>&1; then
  echo "Bankr CLI not found. Install with: bun install -g @bankr/cli" >&2
  exit 1
fi

TOKEN="0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03"
DELEGATEE_LOWER=$(echo "$DELEGATEE" | tr '[:upper:]' '[:lower:]')
ADDR_PADDED=$(printf '%064s' "${DELEGATEE_LOWER#0x}" | tr ' ' '0')

CALLDATA="0x5c19a95c${ADDR_PADDED}"

echo "Delegating voting power to: $DELEGATEE" >&2

RESULT=$(bankr prompt "Submit this transaction: {\"to\": \"$TOKEN\", \"data\": \"$CALLDATA\", \"value\": \"0\", \"chainId\": 1}" 2>&1)

if echo "$RESULT" | grep -q "etherscan.io/tx"; then
  TX_HASH=$(echo "$RESULT" | grep -oE 'etherscan.io/tx/0x[a-fA-F0-9]{64}' | grep -oE '0x[a-fA-F0-9]{64}')
  echo "Delegated to $DELEGATEE" >&2
  echo "TX: https://etherscan.io/tx/$TX_HASH" >&2
  echo "{\"success\":true,\"delegatee\":\"$DELEGATEE\",\"tx\":\"$TX_HASH\"}"
else
  echo "Failed: $RESULT" >&2
  exit 1
fi
