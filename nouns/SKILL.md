---
name: nouns
description: Interact with Nouns DAO on Ethereum. Bid on and settle daily Noun auctions, vote on governance proposals with gas refunds, create proposal candidates, submit proposals, check voting power, view token balances, and delegate votes. Uses Bankr for transaction execution.
metadata: {"clawdbot":{"emoji":"⌐◨-◨","homepage":"https://nouns.wtf","requires":{"bins":["curl","jq"]}}}
---

# Nouns

Nouns DAO generates and auctions one Noun NFT every 24 hours, forever. 100% of auction proceeds go to the DAO treasury, governed by Noun holders. All artwork is stored and rendered on-chain.

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

**Encoding:** Addresses are zero-padded to 32 bytes.

## NounsAuctionHouseV3 Interface

**Contract:** `0x830BD73E4184ceF73443C15111a1DF14e495C706`

| Function | Selector | Params | Returns |
|----------|----------|--------|---------|
| `auction()` | `0x7d9f6db5` | - | (nounId, amount, startTime, endTime, bidder, settled) |
| `reservePrice()` | `0xdb2e1eed` | - | uint192 (minimum bid in wei) |
| `minBidIncrementPercentage()` | `0xb296024d` | - | uint8 (e.g. 2 = 2%) |
| `duration()` | `0x0fb5a6b4` | - | uint256 (auction duration in seconds) |
| `createBid(uint256)` | `0x659dd2b4` | nounId (32B) | (write, payable — send ETH as value) |
| `settleCurrentAndCreateNewAuction()` | `0xf25efffc` | - | (write) |
| `settleAuction()` | `0xa4d0a17e` | - | (write — settle only, no new auction) |

**`auction()` returns** 6 values (192 bytes total):
- bytes 0-31: `nounId` (uint96)
- bytes 32-63: `amount` (uint128, current highest bid in wei)
- bytes 64-95: `startTime` (uint40)
- bytes 96-127: `endTime` (uint40)
- bytes 128-159: `bidder` (address, current highest bidder)
- bytes 160-191: `settled` (bool)

**Bidding rules:**
- Bid must be >= `reservePrice` if no current bid
- Bid must be >= current bid + `minBidIncrementPercentage`%
- Auction extends by `timeBuffer` (typically 5 min) if bid placed near end

## NounsDAOLogicV4 Interface

**Contract:** `0x6f3E6272A167e8AcCb32072d08E0957F9c79223d`

### Read Functions

| Function | Selector | Params | Returns |
|----------|----------|--------|---------|
| `proposalCount()` | `0xda35c664` | - | uint256 |
| `proposalThreshold()` | `0xb58131b0` | - | uint256 (min votes to propose) |
| `state(uint256)` | `0x3e4f49e6` | proposalId (32B) | uint8 (see state enum) |
| `proposals(uint256)` | `0x013cf08b` | proposalId (32B) | ProposalCondensedV2 struct |
| `proposalsV3(uint256)` | `0xe2742e18` | proposalId (32B) | ProposalCondensedV3 struct |
| `adjustedTotalSupply()` | `0x8f1314b6` | - | uint256 (supply minus DAO-held) |
| `getReceipt(uint256,address)` | `0xe23a9a52` | proposalId + addr | (hasVoted, support, votes) |

**Proposal state enum:**

| Value | State | Description |
|-------|-------|-------------|
| 0 | Pending | Waiting for voting to start |
| 1 | Active | Voting in progress |
| 2 | Canceled | Proposal canceled |
| 3 | Defeated | Failed to reach quorum or majority |
| 4 | Succeeded | Passed, ready to queue |
| 5 | Queued | In timelock, waiting for execution |
| 6 | Expired | Queued but not executed in time |
| 7 | Executed | Successfully executed |
| 8 | Vetoed | Vetoed by vetoer |
| 9 | ObjectionPeriod | Only against votes allowed |
| 10 | Updatable | Proposer can still edit |

### Write Functions

| Function | Selector | Params | Returns |
|----------|----------|--------|---------|
| `castRefundableVote(uint256,uint8)` | `0x44fac8f6` | proposalId + support | (write, gas refunded) |
| `castRefundableVoteWithReason(uint256,uint8,string)` | `0x64c05995` | proposalId + support + reason | (write, gas refunded) |
| `castVote(uint256,uint8)` | `0x56781388` | proposalId + support | (write, no refund) |
| `castVoteWithReason(uint256,uint8,string)` | `0x7b3c71d3` | proposalId + support + reason | (write, no refund) |
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
| `updateCandidateCost()` | `0x6549df9f` | - | uint256 (ETH cost in wei for non-Nouners) |
| `createProposalCandidate(...)` | `0x615e4ef9` | targets + values + sigs + calldatas + description + slug + proposalIdToUpdate | (write, payable) |
| `updateProposalCandidate(...)` | `0x848ea72f` | targets + values + sigs + calldatas + description + slug + proposalIdToUpdate + reason | (write, payable) |
| `cancelProposalCandidate(string)` | `0x2a03c079` | slug | (write) |
| `sendFeedback(uint256,uint8,string)` | `0xff4ca184` | proposalId + support + reason | (write) |
| `sendCandidateFeedback(address,string,uint8,string)` | `0x38e861a0` | proposer + slug + support + reason | (write) |

**Candidate rules:**
- Free for Noun holders (>0 voting power), non-Nouners pay `createCandidateCost` in ETH
- Each (proposer, slug) pair can only be used once
- `proposalIdToUpdate` should be `0` for new candidates
- Candidates can gather sponsor signatures and be promoted to proposals via `proposeBySigs`

## Transaction Execution

Use Bankr's arbitrary transaction feature for all write operations:

```json
{
  "to": "0x830BD73E4184ceF73443C15111a1DF14e495C706",
  "data": "0x659dd2b4NOUN_ID_32B_PADDED",
  "value": "BID_AMOUNT_IN_WEI",
  "chainId": 1
}
```

## Workflows

### Check Current Auction

Query `auction()` on AuctionHouse to get the current Noun ID, highest bid, end time, and bidder.
Convert `endTime` from hex to check if auction is still active: `endTime > current_time`.
Convert `amount` from hex wei to ETH: `amount / 1e18`.

### Bid on Auction

1. Query `auction()` to get current `nounId` and `amount`
2. Query `minBidIncrementPercentage()` to calculate minimum bid
3. If first bid: must be >= `reservePrice()`; otherwise >= `amount * (100 + minBidPct) / 100`
4. Submit `createBid(nounId)` via Bankr with `value` set to bid amount in wei

```json
{
  "to": "0x830BD73E4184ceF73443C15111a1DF14e495C706",
  "data": "0x659dd2b4<nounId padded to 32 bytes>",
  "value": "<bid amount in wei>",
  "chainId": 1
}
```

### Settle Auction

When `endTime` has passed and `settled` is false, anyone can settle:

```json
{
  "to": "0x830BD73E4184ceF73443C15111a1DF14e495C706",
  "data": "0xf25efffc",
  "value": "0",
  "chainId": 1
}
```

This settles the current auction and starts a new one.

### Check Voting Power & Delegation

- Query `getCurrentVotes(address)` on NounsToken to get total voting power (own + delegated to you)
- Query `balanceOf(address)` to get number of Nouns owned
- Query `delegates(address)` to see who an address delegates to

### Delegate Votes

Submit `delegate(delegatee)` via Bankr:

```json
{
  "to": "0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03",
  "data": "0x5c19a95c<delegatee address padded to 32 bytes>",
  "value": "0",
  "chainId": 1
}
```

Delegate to yourself to use your own votes. Delegation transfers all voting power.

### Vote on a Proposal

1. Query `state(proposalId)` — must be `1` (Active) or `9` (ObjectionPeriod, against only)
2. Query `getReceipt(proposalId, voter)` to check if already voted
3. Submit `castRefundableVote(proposalId, support)` via Bankr:

```json
{
  "to": "0x6f3E6272A167e8AcCb32072d08E0957F9c79223d",
  "data": "0x44fac8f6<proposalId 32B><support 32B>",
  "value": "0",
  "chainId": 1
}
```

Support: `0x...00` = Against, `0x...01` = For, `0x...02` = Abstain.

### Check Proposal State

Query `state(proposalId)` and `proposals(proposalId)` on the DAO contract to get proposal details and current status.

### Create a Proposal Candidate

1. Query `createCandidateCost()` on NounsDAOData to check fee (free for Nouners)
2. Encode `createProposalCandidate(targets, values, signatures, calldatas, description, slug, 0)` calldata
3. Submit via Bankr with `value` set to the candidate cost (or `"0"` if caller is a Nouner)

## Resources

- **Nouns.wtf:** https://nouns.wtf
- **Governance Docs:** https://docs.nouns.wtf/governance/proposals
- **Deployments:** https://docs.nouns.wtf/protocol/deployments
- **Etherscan (Token):** https://etherscan.io/address/0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03
- **Etherscan (Auction):** https://etherscan.io/address/0x830BD73E4184ceF73443C15111a1DF14e495C706
- **Etherscan (DAO):** https://etherscan.io/address/0x6f3E6272A167e8AcCb32072d08E0957F9c79223d
- **Source Code:** https://github.com/nounsDAO/nouns-monorepo
