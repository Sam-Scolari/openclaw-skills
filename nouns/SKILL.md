---
name: nouns
description: Interact with Nouns DAO on Ethereum. Vote on governance proposals with gas refunds, create proposal candidates, submit proposals, check voting power, view proposal details, check vote receipts, delegate votes, bid on and settle daily Noun auctions. Use when users want to participate in Nouns DAO governance, check proposal status, or manage their voting power.
metadata: {"clawdbot":{"emoji":"⌐◨-◨","homepage":"https://nouns.wtf","requires":{"bins":["curl","jq","node"]}}}
---

# Nouns

Nouns DAO generates and auctions one Noun NFT every 24 hours, forever. 100% of auction proceeds go to the DAO treasury, governed by Noun holders. All artwork is stored and rendered on-chain.

## Scripts

### Queries

| Script | Usage | Description |
|--------|-------|-------------|
| `scripts/voting-power.sh` | `<address>` | Check voting power, balance, and delegation |
| `scripts/proposal.sh` | `<proposal_id>` | Fetch proposal details and current state |
| `scripts/latest-proposal.sh` | (none) | Get the latest proposal ID |
| `scripts/votes.sh` | `<proposal_id> <address>` | Check whether an address voted on a proposal |

### Mutations (via Bankr)

| Script | Usage | Description |
|--------|-------|-------------|
| `scripts/vote.sh` | `<proposal_id> <support> [reason]` | Cast a vote (0=Against, 1=For, 2=Abstain) |
| `scripts/propose.sh` | `<target> <value_wei> <signature> <calldata_hex> <description>` | Submit a single-action proposal |
| `scripts/create-candidate.sh` | `<target> <value_wei> <signature> <calldata_hex> <description> <slug>` | Create a proposal candidate |
| `scripts/update-candidate.sh` | `<target> <value_wei> <signature> <calldata_hex> <description> <slug> <reason>` | Update an existing proposal candidate |
| `scripts/delegate.sh` | `<delegatee_address>` | Delegate voting power to an address |

## Contracts (Ethereum mainnet, chain ID 1)

| Contract | Address |
|----------|---------|
| NounsToken | `0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03` |
| NounsAuctionHouseV3 | `0x830BD73E4184ceF73443C15111a1DF14e495C706` |
| NounsDAOLogicV4 | `0x6f3E6272A167e8AcCb32072d08E0957F9c79223d` |
| NounsDAOData | `0xf790A5f59678dd733fb3De93493A91f472ca1365` |
| NounsDAOExecutorV2 (Treasury) | `0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71` |

## RPC Template

```bash
curl -s -X POST https://eth.llamarpc.com -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"CONTRACT","data":"SELECTOR+PARAMS"},"latest"],"id":1}' | jq -r '.result'
```

## NounsToken Interface

**Contract:** `0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03`

| Function | Selector | Params | Returns |
|----------|----------|--------|---------|
| `balanceOf(address)` | `0x70a08231` | addr (32B padded) | uint256 (number of Nouns owned) |
| `ownerOf(uint256)` | `0x6352211e` | tokenId (32B) | address |
| `totalSupply()` | `0x18160ddd` | - | uint256 |
| `delegates(address)` | `0x587cde1e` | addr (32B padded) | address (current delegate) |
| `getCurrentVotes(address)` | `0xb4b5ea57` | addr (32B padded) | uint256 (voting power) |
| `delegate(address)` | `0x5c19a95c` | addr (32B padded) | (write) |

Addresses are zero-padded to 32 bytes: `0x70a08231` + `000000000000000000000000<address without 0x>`.

## NounsAuctionHouseV3 Interface

**Contract:** `0x830BD73E4184ceF73443C15111a1DF14e495C706`

| Function | Selector | Params | Returns |
|----------|----------|--------|---------|
| `auction()` | `0x7d9f6db5` | - | see layout below |
| `reservePrice()` | `0xdb2e1eed` | - | uint192 (minimum bid in wei) |
| `minBidIncrementPercentage()` | `0xb296024d` | - | uint8 (e.g. 2 = 2%) |
| `duration()` | `0x0fb5a6b4` | - | uint256 (auction duration in seconds) |
| `createBid(uint256)` | `0x659dd2b4` | nounId (32B) | (write, payable — send ETH as value) |
| `settleCurrentAndCreateNewAuction()` | `0xf25efffc` | - | (write) |
| `settleAuction()` | `0xa4d0a17e` | - | (write — settle only, no new auction) |

**`auction()` return layout** — 6 words, 192 bytes:

| Word | Offset (hex chars) | Field | Type |
|------|-------------------|-------|------|
| 0 | 0–63 | nounId | uint96 |
| 1 | 64–127 | amount | uint128 (current highest bid in wei) |
| 2 | 128–191 | startTime | uint40 (unix timestamp) |
| 3 | 192–255 | endTime | uint40 (unix timestamp) |
| 4 | 256–319 | bidder | address (rightmost 40 hex chars) |
| 5 | 320–383 | settled | bool (0 or 1) |

Decode: strip `0x`, slice word N as `hex.slice(N*64, (N+1)*64)`, parse with `parseInt(word, 16)`. Addresses: `'0x' + word.slice(24)`.

## NounsDAOLogicV4 Interface

**Contract:** `0x6f3E6272A167e8AcCb32072d08E0957F9c79223d`

### Read Functions

| Function | Selector | Params | Returns |
|----------|----------|--------|---------|
| `proposalCount()` | `0xda35c664` | - | uint256 |
| `proposalThreshold()` | `0xb58131b0` | - | uint256 (min votes to propose) |
| `state(uint256)` | `0x3e4f49e6` | proposalId (32B) | uint8 (see state enum) |
| `proposals(uint256)` | `0x013cf08b` | proposalId (32B) | ProposalCondensedV2 (use `scripts/proposal.sh` to decode) |
| `adjustedTotalSupply()` | `0x8f1314b6` | - | uint256 (supply minus DAO-held) |
| `getReceipt(uint256,address)` | `0xe23a9a52` | proposalId + addr | (hasVoted, support, votes) — use `scripts/votes.sh` to decode |

**Proposal state enum:** 0=Pending, 1=Active, 2=Canceled, 3=Defeated, 4=Succeeded, 5=Queued, 6=Expired, 7=Executed, 8=Vetoed, 9=ObjectionPeriod, 10=Updatable

### Write Functions

| Function | Selector | Params | Returns |
|----------|----------|--------|---------|
| `castRefundableVote(uint256,uint8)` | `0x44fac8f6` | proposalId + support | (write, gas refunded) |
| `castRefundableVoteWithReason(uint256,uint8,string)` | `0x64c05995` | proposalId + support + reason | (write, gas refunded) |
| `propose(address[],uint256[],string[],bytes[],string)` | `0xda95691a` | targets + values + sigs + calldatas + description | (write) |
| `queue(uint256)` | `0xddf0b009` | proposalId | (write) |
| `execute(uint256)` | `0xfe0d94c1` | proposalId | (write) |
| `cancel(uint256)` | `0x40e58ee5` | proposalId | (write) |

**Vote support values:** `0` = Against, `1` = For, `2` = Abstain

Prefer `castRefundableVote` / `castRefundableVoteWithReason` — the DAO refunds gas costs to voters with > 0 voting power.

For detailed governance mechanics, see [references/governance.md](references/governance.md).

## NounsDAOData Interface

**Contract:** `0xf790A5f59678dd733fb3De93493A91f472ca1365`

| Function | Selector | Params | Returns |
|----------|----------|--------|---------|
| `createCandidateCost()` | `0x628ff474` | - | uint256 (ETH cost in wei for non-Nouners) |
| `createProposalCandidate(...)` | `0x615e4ef9` | targets + values + sigs + calldatas + description + slug + proposalIdToUpdate | (write, payable) |
| `updateProposalCandidate(...)` | `0x848ea72f` | same as create + reason | (write, payable) |
| `cancelProposalCandidate(string)` | `0x2a03c079` | slug | (write) |
| `sendFeedback(uint256,uint8,string)` | `0xff4ca184` | proposalId + support + reason | (write) |

Free for Noun holders (>0 voting power), non-Nouners pay `createCandidateCost` in ETH. Each (proposer, slug) pair can only be used once. Set `proposalIdToUpdate` to `0` for new candidates.

## Transaction Execution

Use Bankr's arbitrary transaction feature for all write operations:

```json
{
  "to": "0xContractAddress",
  "data": "0xSELECTOR+ABI_ENCODED_PARAMS",
  "value": "0",
  "chainId": 1
}
```

## Workflows

### Check Voting Power & Delegation

Run `scripts/voting-power.sh <address>` to see Nouns owned, voting power, and delegation target.

To delegate, run `scripts/delegate.sh <delegatee_address>`. Delegate to yourself to activate your own votes.

### Vote on a Proposal

1. Run `scripts/proposal.sh <id>` to check state (must be Active=1 or ObjectionPeriod=9)
2. Run `scripts/votes.sh <id> <voter_address>` to check if already voted
3. Run `scripts/vote.sh <id> <support>` to cast vote (0=Against, 1=For, 2=Abstain)

### Check Proposal

Run `scripts/proposal.sh <id>` for full details, or `scripts/latest-proposal.sh` for the most recent proposal ID.

### Submit a Proposal

Requires >= `proposalThreshold()` votes (currently ~3). Only one active proposal per account.

Run `scripts/propose.sh <target> <value_wei> <signature> <calldata_hex> <description>`.

Example — transfer 10 ETH from treasury:
```bash
scripts/propose.sh \
  0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71 \
  0 \
  "sendETH(address,uint256)" \
  "0x000000000000000000000000RECIPIENT0000000000000000000000000000000000000000000000008ac7230489e80000" \
  "# Transfer 10 ETH\nFund project XYZ"
```

### Create a Proposal Candidate

Run `scripts/create-candidate.sh <target> <value_wei> <signature> <calldata_hex> <description> <slug>`.

Candidates gather community feedback and sponsor signatures before promotion to a full proposal.

### Bid on Auction

1. Query `auction()` on AuctionHouse to get current `nounId` and `amount`
2. Bid must be >= `reservePrice()` (first bid) or >= current bid + `minBidIncrementPercentage`%
3. Submit via Bankr: `createBid(nounId)` with `value` = bid amount in wei

```json
{
  "to": "0x830BD73E4184ceF73443C15111a1DF14e495C706",
  "data": "0x659dd2b4<nounId padded to 32 bytes>",
  "value": "<bid amount in wei>",
  "chainId": 1
}
```

### Settle Auction

When `endTime` has passed and `settled` is false:

```json
{
  "to": "0x830BD73E4184ceF73443C15111a1DF14e495C706",
  "data": "0xf25efffc",
  "value": "0",
  "chainId": 1
}
```

## Resources

- **Nouns.wtf:** https://nouns.wtf
- **Governance Docs:** https://docs.nouns.wtf/governance/proposals
- **Etherscan (DAO):** https://etherscan.io/address/0x6f3E6272A167e8AcCb32072d08E0957F9c79223d
- **Source Code:** https://github.com/nounsDAO/nouns-monorepo
