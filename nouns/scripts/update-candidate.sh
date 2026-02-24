#!/bin/bash
# Update an existing Nouns DAO proposal candidate
# Usage: ./update-candidate.sh <target> <value_wei> <signature> <calldata_hex> <description> <slug> <reason>
#
# Example:
#   ./update-candidate.sh \
#     0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71 \
#     0 \
#     "sendETH(address,uint256)" \
#     "0x000000000000000000000000RECIPIENT...0000000000000000000000000000000000000000000000008ac7230489e80000" \
#     "# My Proposal v2\nUpdated: increased funding to 10 ETH" \
#     "my-unique-slug" \
#     "Updated funding amount"
#
# Free for Noun holders (>0 voting power). Non-holders pay updateCandidateCost() in ETH.
# The slug must match the original candidate's slug.

set -euo pipefail

TARGET="${1:?Usage: update-candidate.sh <target> <value_wei> <signature> <calldata_hex> <description> <slug> <reason>}"
VALUE="${2:?Missing value_wei}"
SIGNATURE="${3:?Missing function signature}"
CALLDATA_HEX="${4:?Missing calldata hex}"
DESCRIPTION="${5:?Missing description}"
SLUG="${6:?Missing slug}"
REASON="${7:?Missing reason}"

if ! command -v bankr >/dev/null 2>&1; then
  echo "Bankr CLI not found. Install with: bun install -g @bankr/cli" >&2
  exit 1
fi

DAO_DATA="0xf790A5f59678dd733fb3De93493A91f472ca1365"
RPC_URL="https://eth.llamarpc.com"

# Check candidate update cost
COST_HEX=$(curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"'"$DAO_DATA"'","data":"0x6549df9f"},"latest"],"id":1}' | jq -r '.result')

COST_WEI=$(node -e "console.log(BigInt('${COST_HEX}').toString())")

echo "Updating proposal candidate..." >&2
echo "Target:      $TARGET" >&2
echo "Slug:        $SLUG" >&2
echo "Reason:      $REASON" >&2
echo "Cost:        $COST_WEI wei (free for Noun holders)" >&2

# updateProposalCandidate(address[],uint256[],string[],bytes[],string,string,uint256,string)
# selector: 0x848ea72f
# 8 params: same as create but with reason appended, proposalIdToUpdate=0
ENCODED=$(node -e "
const target = '${TARGET}'.toLowerCase().replace('0x','');
const value = BigInt('${VALUE}');
const signature = '${SIGNATURE}';
const calldataHex = '${CALLDATA_HEX}'.replace('0x','');
const description = \`${DESCRIPTION}\`;
const slug = '${SLUG}';
const reason = \`${REASON}\`;

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

// 8 params: targets[], values[], signatures[], calldatas[], description, slug, proposalIdToUpdate, reason
const headSize = 8 * 32;

const targetsD = eu256(1) + eAddr(target);
const valuesD = eu256(1) + eu256(value);
const sigsD = eu256(1) + eu256(32) + eStr(signature);
const cdsD = eu256(1) + eu256(32) + eBytes(calldataHex);
const descD = eStr(description);
const slugD = eStr(slug);
const pidUpdate = eu256(0);
const reasonD = eStr(reason);

// 7 dynamic offsets + 1 static (proposalIdToUpdate) + 1 dynamic offset (reason)
// Layout: offset0..offset5, pidUpdate, offset7
const dynamicBefore = [targetsD, valuesD, sigsD, cdsD, descD, slugD];
const offsets = [];
let pos = headSize;

for (const p of dynamicBefore) {
  offsets.push(eu256(pos));
  pos += p.length / 2;
}

// pidUpdate is static, inline
// reason offset comes after pidUpdate in the head
const reasonOffset = eu256(pos);

const head = offsets.join('') + pidUpdate + reasonOffset;
console.log('0x848ea72f' + head + dynamicBefore.join('') + reasonD);
")

RESULT=$(bankr prompt "Submit this transaction: {\"to\": \"$DAO_DATA\", \"data\": \"$ENCODED\", \"value\": \"$COST_WEI\", \"chainId\": 1}" 2>&1)

if echo "$RESULT" | grep -q "etherscan.io/tx"; then
  TX_HASH=$(echo "$RESULT" | grep -oE 'etherscan.io/tx/0x[a-fA-F0-9]{64}' | grep -oE '0x[a-fA-F0-9]{64}')
  echo "Candidate updated!" >&2
  echo "TX: https://etherscan.io/tx/$TX_HASH" >&2
  echo "{\"success\":true,\"slug\":\"$SLUG\",\"tx\":\"$TX_HASH\"}"
else
  echo "Failed: $RESULT" >&2
  exit 1
fi
