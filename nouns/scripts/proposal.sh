#!/bin/bash
# Fetch Nouns DAO proposal details by ID
# Usage: ./proposal.sh <proposal_id>
# Example: ./proposal.sh 941
#
# Calls proposals(uint256) which returns ProposalCondensedV2 (15 words):
#   Word  0: id (uint256)
#   Word  1: proposer (address)
#   Word  2: proposalThreshold (uint256)
#   Word  3: quorumVotes (uint256)
#   Word  4: eta (uint256) — execution timestamp, 0 if not queued
#   Word  5: startBlock (uint256)
#   Word  6: endBlock (uint256)
#   Word  7: forVotes (uint256)
#   Word  8: againstVotes (uint256)
#   Word  9: abstainVotes (uint256)
#   Word 10: canceled (bool)
#   Word 11: vetoed (bool)
#   Word 12: executed (bool)
#   Word 13: totalSupply (uint256) — snapshot at creation
#   Word 14: creationBlock (uint256)

set -euo pipefail

PROPOSAL_ID="${1:?Usage: proposal.sh <proposal_id>}"

RPC_URL="https://eth.llamarpc.com"
DAO="0x6f3E6272A167e8AcCb32072d08E0957F9c79223d"

ID_PADDED=$(printf '%064x' "$PROPOSAL_ID")

rpc_call() {
  curl -s -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$DAO\",\"data\":\"$1\"},\"latest\"],\"id\":1}" | jq -r '.result'
}

PROPOSAL_HEX=$(rpc_call "0x013cf08b${ID_PADDED}")
STATE_HEX=$(rpc_call "0x3e4f49e6${ID_PADDED}")

if [ "$PROPOSAL_HEX" = "null" ] || [ -z "$PROPOSAL_HEX" ] || [ "$PROPOSAL_HEX" = "0x" ]; then
  echo "Error: Proposal $PROPOSAL_ID not found" >&2
  exit 1
fi

STATE_NUM=$((16#${STATE_HEX: -2}))

STATE_NAMES=("Pending" "Active" "Canceled" "Defeated" "Succeeded" "Queued" "Expired" "Executed" "Vetoed" "ObjectionPeriod" "Updatable")
STATE_NAME="${STATE_NAMES[$STATE_NUM]:-Unknown}"

node -e "
const hex = '${PROPOSAL_HEX}'.replace('0x','');
const w = (i) => hex.slice(i*64, (i+1)*64);
const num = (i) => parseInt(w(i), 16);
const addr = (i) => '0x' + w(i).slice(24);
const bool = (i) => parseInt(w(i), 16) !== 0;

const p = {
  id: num(0),
  proposer: addr(1),
  proposalThreshold: num(2),
  quorumVotes: num(3),
  eta: num(4),
  startBlock: num(5),
  endBlock: num(6),
  forVotes: num(7),
  againstVotes: num(8),
  abstainVotes: num(9),
  canceled: bool(10),
  vetoed: bool(11),
  executed: bool(12),
  totalSupply: num(13),
  creationBlock: num(14),
  state: '${STATE_NAME}'
};

console.log('Proposal #' + p.id);
console.log('State:              ' + p.state);
console.log('Proposer:           ' + p.proposer);
console.log('Proposal Threshold: ' + p.proposalThreshold);
console.log('Quorum Required:    ' + p.quorumVotes);
console.log('Votes For:          ' + p.forVotes);
console.log('Votes Against:      ' + p.againstVotes);
console.log('Votes Abstain:      ' + p.abstainVotes);
console.log('Start Block:        ' + p.startBlock);
console.log('End Block:          ' + p.endBlock);
console.log('Creation Block:     ' + p.creationBlock);
console.log('Total Supply:       ' + p.totalSupply);
if (p.eta > 0) console.log('ETA (timestamp):    ' + p.eta + ' (' + new Date(p.eta * 1000).toISOString() + ')');
if (p.canceled) console.log('CANCELED');
if (p.vetoed) console.log('VETOED');
if (p.executed) console.log('EXECUTED');
"
