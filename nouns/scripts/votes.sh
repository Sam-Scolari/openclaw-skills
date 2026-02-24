#!/bin/bash
# Check whether an address voted on a Nouns DAO proposal
# Usage: ./votes.sh <proposal_id> <address>
# Example: ./votes.sh 941 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5
#
# Calls getReceipt(uint256,address) which returns 3 words:
#   Word 0: hasVoted (bool)
#   Word 1: support (uint8) — 0=Against, 1=For, 2=Abstain
#   Word 2: votes (uint96) — number of votes cast

set -euo pipefail

PROPOSAL_ID="${1:?Usage: votes.sh <proposal_id> <address>}"
ADDRESS="${2:?Usage: votes.sh <proposal_id> <address>}"
ADDRESS_LOWER=$(echo "$ADDRESS" | tr '[:upper:]' '[:lower:]')

RPC_URL="https://eth.llamarpc.com"
DAO="0x6f3E6272A167e8AcCb32072d08E0957F9c79223d"

ID_PADDED=$(printf '%064x' "$PROPOSAL_ID")
ADDR_PADDED=$(printf '%064s' "${ADDRESS_LOWER#0x}" | tr ' ' '0')

RESULT=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$DAO\",\"data\":\"0xe23a9a52${ID_PADDED}${ADDR_PADDED}\"},\"latest\"],\"id\":1}" | jq -r '.result')

if [ "$RESULT" = "null" ] || [ -z "$RESULT" ]; then
  echo "Error: Failed to fetch vote receipt" >&2
  exit 1
fi

node -e "
const hex = '${RESULT}'.replace('0x','');
const w = (i) => hex.slice(i*64, (i+1)*64);
const hasVoted = parseInt(w(0), 16) !== 0;
const support = parseInt(w(1), 16);
const votes = parseInt(w(2), 16);
const supportStr = ['Against', 'For', 'Abstain'][support] || 'Unknown';

console.log('Proposal:  #${PROPOSAL_ID}');
console.log('Address:   ${ADDRESS}');
console.log('Has Voted: ' + hasVoted);
if (hasVoted) {
  console.log('Vote:      ' + supportStr + ' (' + support + ')');
  console.log('Votes:     ' + votes);
}
"
