#!/bin/bash
# Submit a Nouns DAO proposal (single action)
# Usage: ./propose.sh <target> <value_wei> <signature> <calldata_hex> <description>
#
# Example — Transfer 10 ETH from treasury:
#   ./propose.sh \
#     0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71 \
#     0 \
#     "sendETH(address,uint256)" \
#     "$(node -e "
#       const addr = '000000000000000000000000RECIPIENT_ADDR_HERE';
#       const amt = BigInt(10n * 10n**18n).toString(16).padStart(64, '0');
#       console.log('0x' + addr + amt);
#     ")" \
#     "# Transfer 10 ETH\nSend 10 ETH to recipient for project funding."
#
# Requires >= proposalThreshold() votes (currently ~3).
# Only one active proposal per account at a time.

set -euo pipefail

TARGET="${1:?Usage: propose.sh <target> <value_wei> <signature> <calldata_hex> <description>}"
VALUE="${2:?Missing value_wei}"
SIGNATURE="${3:?Missing function signature}"
CALLDATA_HEX="${4:?Missing calldata hex}"
DESCRIPTION="${5:?Missing description}"

if ! command -v bankr >/dev/null 2>&1; then
  echo "Bankr CLI not found. Install with: bun install -g @bankr/cli" >&2
  exit 1
fi

DAO="0x6f3E6272A167e8AcCb32072d08E0957F9c79223d"

# propose(address[],uint256[],string[],bytes[],string) = 0xda95691a
# ABI encodes 5 dynamic parameters for a single-action proposal
ENCODED=$(node -e "
const target = '${TARGET}'.toLowerCase().replace('0x','');
const value = BigInt('${VALUE}');
const signature = '${SIGNATURE}';
const calldataHex = '${CALLDATA_HEX}'.replace('0x','');
const description = \`${DESCRIPTION}\`;

function encodeUint256(n) {
  return BigInt(n).toString(16).padStart(64, '0');
}

function encodeAddress(a) {
  return a.toLowerCase().padStart(64, '0');
}

function encodeString(s) {
  const hex = Buffer.from(s, 'utf8').toString('hex');
  const len = encodeUint256(s.length);
  const padded = hex.padEnd(Math.ceil(hex.length / 64) * 64, '0');
  return len + padded;
}

function encodeBytes(hexStr) {
  const byteLen = hexStr.length / 2;
  const len = encodeUint256(byteLen);
  const padded = hexStr.padEnd(Math.ceil(hexStr.length / 64) * 64, '0');
  return len + padded;
}

// Head: 5 offsets for dynamic params
// Each offset is relative to the start of the encoding (after selector)
const headSize = 5 * 32; // 160 bytes = 0xa0

// Encode each array/value
// targets: address[] with 1 element
const targetsData = encodeUint256(1) + encodeAddress(target);
// values: uint256[] with 1 element
const valuesData = encodeUint256(1) + encodeUint256(value);
// signatures: string[] with 1 element
const sigDataInner = encodeString(signature);
const signaturesData = encodeUint256(1) + encodeUint256(32) + sigDataInner;
// calldatas: bytes[] with 1 element
const cdDataInner = encodeBytes(calldataHex);
const calldatasData = encodeUint256(1) + encodeUint256(32) + cdDataInner;
// description: string
const descriptionData = encodeString(description);

// Calculate offsets
const offsetTargets = headSize;
const offsetValues = offsetTargets + (targetsData.length / 2);
const offsetSignatures = offsetValues + (valuesData.length / 2);
const offsetCalldatas = offsetSignatures + (signaturesData.length / 2);
const offsetDescription = offsetCalldatas + (calldatasData.length / 2);

const head = encodeUint256(offsetTargets) + encodeUint256(offsetValues) +
             encodeUint256(offsetSignatures) + encodeUint256(offsetCalldatas) +
             encodeUint256(offsetDescription);

console.log('0xda95691a' + head + targetsData + valuesData + signaturesData + calldatasData + descriptionData);
")

echo "Submitting proposal to Nouns DAO..." >&2
echo "Target:      $TARGET" >&2
echo "Value:       $VALUE wei" >&2
echo "Signature:   $SIGNATURE" >&2
echo "Description: $(echo "$DESCRIPTION" | head -1)" >&2

RESULT=$(bankr prompt "Submit this transaction: {\"to\": \"$DAO\", \"data\": \"$ENCODED\", \"value\": \"0\", \"chainId\": 1}" 2>&1)

if echo "$RESULT" | grep -q "etherscan.io/tx"; then
  TX_HASH=$(echo "$RESULT" | grep -oE 'etherscan.io/tx/0x[a-fA-F0-9]{64}' | grep -oE '0x[a-fA-F0-9]{64}')
  echo "Proposal submitted!" >&2
  echo "TX: https://etherscan.io/tx/$TX_HASH" >&2
  echo "{\"success\":true,\"tx\":\"$TX_HASH\"}"
else
  echo "Failed: $RESULT" >&2
  exit 1
fi
