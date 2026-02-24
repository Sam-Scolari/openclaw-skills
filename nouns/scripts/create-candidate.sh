#!/bin/bash
# Create a Nouns DAO proposal candidate
# Usage: ./create-candidate.sh <target> <value_wei> <signature> <calldata_hex> <description> <slug>
#
# Example:
#   ./create-candidate.sh \
#     0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71 \
#     0 \
#     "sendETH(address,uint256)" \
#     "0x000000000000000000000000RECIPIENT...0000000000000000000000000000000000000000000000008ac7230489e80000" \
#     "# My Proposal\nFund a project with 10 ETH" \
#     "my-unique-slug"
#
# Free for Noun holders (>0 voting power). Non-holders pay createCandidateCost() in ETH.
# Each (proposer, slug) pair can only be used once.

set -euo pipefail

TARGET="${1:?Usage: create-candidate.sh <target> <value_wei> <signature> <calldata_hex> <description> <slug>}"
VALUE="${2:?Missing value_wei}"
SIGNATURE="${3:?Missing function signature}"
CALLDATA_HEX="${4:?Missing calldata hex}"
DESCRIPTION="${5:?Missing description}"
SLUG="${6:?Missing slug}"

if ! command -v bankr >/dev/null 2>&1; then
  echo "Bankr CLI not found. Install with: bun install -g @bankr/cli" >&2
  exit 1
fi

DAO_DATA="0xf790A5f59678dd733fb3De93493A91f472ca1365"
RPC_URL="https://eth.llamarpc.com"

# Check candidate creation cost
COST_HEX=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"'"$DAO_DATA"'","data":"0x628ff474"},"latest"],"id":1}' | jq -r '.result')

COST_WEI=$(node -e "console.log(BigInt('${COST_HEX}').toString())")

echo "Creating proposal candidate..." >&2
echo "Target:      $TARGET" >&2
echo "Slug:        $SLUG" >&2
echo "Cost:        $COST_WEI wei (free for Noun holders)" >&2

# createProposalCandidate(address[],uint256[],string[],bytes[],string,string,uint256)
# selector: 0x615e4ef9
# 7 dynamic/mixed parameters, proposalIdToUpdate=0 for new candidates
ENCODED=$(node -e "
const target = '${TARGET}'.toLowerCase().replace('0x','');
const value = BigInt('${VALUE}');
const signature = '${SIGNATURE}';
const calldataHex = '${CALLDATA_HEX}'.replace('0x','');
const description = \`${DESCRIPTION}\`;
const slug = '${SLUG}';

function eu256(n) { return BigInt(n).toString(16).padStart(64, '0'); }
function eAddr(a) { return a.toLowerCase().padStart(64, '0'); }
function eStr(s) {
  const hex = Buffer.from(s, 'utf8').toString('hex');
  return eu256(s.length) + hex.padEnd(Math.ceil(hex.length / 64) * 64, '0');
}
function eBytes(h) {
  const byteLen = h.length / 2;
  return eu256(byteLen) + h.padEnd(Math.ceil(h.length / 64) * 64, '0');
}

// 7 params: targets[], values[], signatures[], calldatas[], description, slug, proposalIdToUpdate
const headSize = 7 * 32;

const targetsD = eu256(1) + eAddr(target);
const valuesD = eu256(1) + eu256(value);
const sigsD = eu256(1) + eu256(32) + eStr(signature);
const cdsD = eu256(1) + eu256(32) + eBytes(calldataHex);
const descD = eStr(description);
const slugD = eStr(slug);
const pidUpdate = eu256(0);

// Build sequentially and track offsets
let tail = '';
const parts = [targetsD, valuesD, sigsD, cdsD, descD, slugD];
const offsets = [];
let pos = headSize;

// First 6 are dynamic (offsets), 7th is static (inline uint256)
for (const p of parts) {
  offsets.push(eu256(pos));
  pos += p.length / 2;
}

const head = offsets.join('') + pidUpdate;
console.log('0x615e4ef9' + head + parts.join(''));
")

RESULT=$(bankr prompt "Submit this transaction: {\"to\": \"$DAO_DATA\", \"data\": \"$ENCODED\", \"value\": \"$COST_WEI\", \"chainId\": 1}" 2>&1)

if echo "$RESULT" | grep -q "etherscan.io/tx"; then
  TX_HASH=$(echo "$RESULT" | grep -oE 'etherscan.io/tx/0x[a-fA-F0-9]{64}' | grep -oE '0x[a-fA-F0-9]{64}')
  echo "Candidate created!" >&2
  echo "TX: https://etherscan.io/tx/$TX_HASH" >&2
  echo "{\"success\":true,\"slug\":\"$SLUG\",\"tx\":\"$TX_HASH\"}"
else
  echo "Failed: $RESULT" >&2
  exit 1
fi
