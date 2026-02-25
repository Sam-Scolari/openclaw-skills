#!/bin/bash
# Cancel a Nouns DAO proposal candidate
# Usage: ./cancel-candidate.sh <slug>
# Example: ./cancel-candidate.sh "my-unique-slug"
#
# Only the original proposer can cancel their candidate.

set -euo pipefail

SLUG="${1:?Usage: cancel-candidate.sh <slug>}"

if ! command -v bankr >/dev/null 2>&1; then
  echo "Bankr CLI not found. Install with: bun install -g @bankr/cli" >&2
  exit 1
fi

DAO_DATA="0xf790A5f59678dd733fb3De93493A91f472ca1365"

# cancelProposalCandidate(string) = 0x2a03c079
CALLDATA=$(node -e "
const slug = '${SLUG}';
const selector = '0x2a03c079';
const offset = '0000000000000000000000000000000000000000000000000000000000000020';
const len = slug.length.toString(16).padStart(64, '0');
const data = Buffer.from(slug, 'utf8').toString('hex').padEnd(Math.ceil(slug.length / 32) * 64, '0');
console.log(selector + offset + len + data);
")

echo "Canceling proposal candidate: $SLUG" >&2

RESULT=$(bankr prompt "Submit this transaction: {\"to\": \"$DAO_DATA\", \"data\": \"$CALLDATA\", \"value\": \"0\", \"chainId\": 1}" 2>&1)

if echo "$RESULT" | grep -q "etherscan.io/tx"; then
  TX_HASH=$(echo "$RESULT" | grep -oE 'etherscan.io/tx/0x[a-fA-F0-9]{64}' | grep -oE '0x[a-fA-F0-9]{64}')
  echo "Candidate canceled!" >&2
  echo "TX: https://etherscan.io/tx/$TX_HASH" >&2
  echo "{\"success\":true,\"slug\":\"$SLUG\",\"tx\":\"$TX_HASH\"}"
else
  echo "Failed: $RESULT" >&2
  exit 1
fi
