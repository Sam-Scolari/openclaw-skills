#!/bin/bash
# Check Nouns DAO voting power, balance, and delegation for an address
# Usage: ./voting-power.sh <address>
# Example: ./voting-power.sh 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5

set -euo pipefail

ADDRESS="${1:?Usage: voting-power.sh <address>}"
ADDRESS_LOWER=$(echo "$ADDRESS" | tr '[:upper:]' '[:lower:]')

RPC_URL="https://eth.llamarpc.com"
TOKEN="0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03"

ADDR_PADDED=$(printf '%064s' "${ADDRESS_LOWER#0x}" | tr ' ' '0')

rpc_call() {
  curl -s -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$TOKEN\",\"data\":\"$1\"},\"latest\"],\"id\":1}" | jq -r '.result'
}

VOTES_HEX=$(rpc_call "0xb4b5ea57${ADDR_PADDED}")
BALANCE_HEX=$(rpc_call "0x70a08231${ADDR_PADDED}")
DELEGATE_HEX=$(rpc_call "0x587cde1e${ADDR_PADDED}")

VOTES=$((16#${VOTES_HEX: -8}))
BALANCE=$((16#${BALANCE_HEX: -8}))
DELEGATE="0x${DELEGATE_HEX: -40}"

echo "Address:        $ADDRESS"
echo "Nouns Owned:    $BALANCE"
echo "Voting Power:   $VOTES"
echo "Delegated To:   $DELEGATE"

DELEGATE_LOWER=$(echo "$DELEGATE" | tr '[:upper:]' '[:lower:]')
if [ "$DELEGATE" = "0x0000000000000000000000000000000000000000" ]; then
  echo "Status:         Not delegated (votes inactive — must delegate to self or another address)"
elif [ "$DELEGATE_LOWER" = "0x${ADDRESS_LOWER#0x}" ]; then
  echo "Status:         Self-delegated"
else
  echo "Status:         Delegated to another address"
fi
