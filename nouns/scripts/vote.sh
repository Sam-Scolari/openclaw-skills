#!/bin/bash
# Cast a vote on a Nouns DAO proposal (with gas refund)
# Usage: ./vote.sh <proposal_id> <support> [reason]
# Example: ./vote.sh 941 1                    # Vote FOR
# Example: ./vote.sh 941 0 "Against because..." # Vote AGAINST with reason
#
# Support values: 0=Against, 1=For, 2=Abstain
# Uses castRefundableVote (gas is refunded by the DAO for voters with >0 voting power)

set -euo pipefail

PROPOSAL_ID="${1:?Usage: vote.sh <proposal_id> <support> [reason]}"
SUPPORT="${2:?Usage: vote.sh <proposal_id> <support> [reason]. Support: 0=Against, 1=For, 2=Abstain}"
REASON="${3:-}"

if ! command -v bankr >/dev/null 2>&1; then
  echo "Bankr CLI not found. Install with: bun install -g @bankr/cli" >&2
  exit 1
fi

if [ "$SUPPORT" -lt 0 ] || [ "$SUPPORT" -gt 2 ]; then
  echo "Invalid support value: $SUPPORT (must be 0=Against, 1=For, 2=Abstain)" >&2
  exit 1
fi

DAO="0x6f3E6272A167e8AcCb32072d08E0957F9c79223d"
ID_PADDED=$(printf '%064x' "$PROPOSAL_ID")
SUPPORT_PADDED=$(printf '%064x' "$SUPPORT")

SUPPORT_NAMES=("Against" "For" "Abstain")

if [ -n "$REASON" ]; then
  # castRefundableVoteWithReason(uint256,uint8,string) = 0x64c05995
  CALLDATA=$(node -e "
const id = '${ID_PADDED}';
const support = '${SUPPORT_PADDED}';
const reason = '${REASON}';
const selector = '0x64c05995';
const offset = '0000000000000000000000000000000000000000000000000000000000000060';
const len = reason.length.toString(16).padStart(64, '0');
const data = Buffer.from(reason, 'utf8').toString('hex').padEnd(Math.ceil(reason.length / 32) * 64, '0');
console.log(selector + id + support + offset + len + data);
")
  echo "Voting ${SUPPORT_NAMES[$SUPPORT]} on Proposal #$PROPOSAL_ID with reason" >&2
else
  # castRefundableVote(uint256,uint8) = 0x44fac8f6
  CALLDATA="0x44fac8f6${ID_PADDED}${SUPPORT_PADDED}"
  echo "Voting ${SUPPORT_NAMES[$SUPPORT]} on Proposal #$PROPOSAL_ID" >&2
fi

RESULT=$(bankr prompt "Submit this transaction: {\"to\": \"$DAO\", \"data\": \"$CALLDATA\", \"value\": \"0\", \"chainId\": 1}" 2>&1)

if echo "$RESULT" | grep -q "etherscan.io/tx"; then
  TX_HASH=$(echo "$RESULT" | grep -oE 'etherscan.io/tx/0x[a-fA-F0-9]{64}' | grep -oE '0x[a-fA-F0-9]{64}')
  echo "Voted ${SUPPORT_NAMES[$SUPPORT]} on Proposal #$PROPOSAL_ID" >&2
  echo "TX: https://etherscan.io/tx/$TX_HASH" >&2
  echo "{\"success\":true,\"proposalId\":$PROPOSAL_ID,\"support\":\"${SUPPORT_NAMES[$SUPPORT]}\",\"tx\":\"$TX_HASH\"}"
else
  echo "Failed: $RESULT" >&2
  exit 1
fi
