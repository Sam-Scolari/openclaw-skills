# Nouns DAO Governance Reference

## Proposal Lifecycle

Proposals follow this state machine:

```
Updatable (2.5 days) → Pending (0.5 days) → Active (4 days) → Succeeded → Queued (2 days) → Executable (21 day grace)
                                                  ↓                                              ↓
                                              Defeated                                        Expired
                                                  ↑
                                          ObjectionPeriod (conditional)
```

Minimum time from proposal to execution: **9 days**.

| State | Duration | Description |
|-------|----------|-------------|
| Updatable | 2.5 days | Proposer can edit transactions and description |
| Pending | 0.5 days | Frozen; vote snapshot taken at end of this period |
| Active | 4 days | Voting open (For, Against, Abstain) |
| ObjectionPeriod | conditional | Only Against votes; triggered by last-minute swing |
| Succeeded | until queued | Passed; anyone can call `queue()` |
| Queued | 2 days | Timelock period before execution |
| Executable | 21 day grace | Anyone can call `execute()`; expires if not executed |

## Who Can Propose

- Must have >= `proposalThreshold()` votes (currently ~3 votes, computed as BPS of `adjustedTotalSupply`)
- Each account can only have one active (non-terminal) proposal at a time
- `adjustedTotalSupply` = total supply minus Nouns held by treasury or fork escrow

### ProposeBySigs

Nouners can pool voting power to meet the proposal threshold by co-signing with EIP-712 signatures. The proposer submits via `proposeBySigs()` with an array of signer signatures. Co-signers become co-proposers and can cancel the proposal.

## Voting

### Support Values

| Value | Meaning |
|-------|---------|
| 0 | Against |
| 1 | For |
| 2 | Abstain |

### Refundable Voting

Use `castRefundableVote` or `castRefundableVoteWithReason` for gas refunds. The DAO refunds gas to voters with > 0 voting power. Refunds are capped at 200 gwei basefee + 2 gwei priority fee, up to 200K gas units. Voting proceeds regardless of whether the refund succeeds.

### Objection Period

If a proposal flips from defeated to passing during the last-minute window of voting, an objection period activates. During this period, only Against votes are accepted, preventing last-minute vote manipulation.

### Vote Snapshot

Voting power is snapshot after the Pending period (not at proposal creation). This gives Nouners time to rearrange delegations in response to a proposal.

## Dynamic Quorum

Proposals require simple majority (more For than Against) plus meeting the dynamic quorum threshold:

- Base quorum: ~108 votes (with 0 Against votes)
- Quorum increases by ~0.98 per Against vote
- Maximum quorum: ~162 votes (reached at ~55 Against votes)
- Abstain votes do not affect quorum
- Quorum is specified as BPS of total supply, so it scales with supply

## Proposal Candidates

Candidates are pre-proposals posted via the NounsDAOData contract:

1. **Create** — Call `createProposalCandidate` with proposal transactions, description, and a unique slug
   - Free for Nouners (>0 voting power), non-Nouners pay `createCandidateCost` in ETH
   - Each (proposer, slug) pair is one-use
2. **Gather feedback** — Community provides onchain feedback via `sendCandidateFeedback`
3. **Update** — Proposer can revise via `updateProposalCandidate` (costs `updateCandidateCost` for non-Nouners)
4. **Promote** — Once enough sponsors sign, submit as a real proposal via `proposeBySigs` on the DAO
5. **Cancel** — Proposer can cancel via `cancelProposalCandidate`

### Proposal Feedback

- `sendFeedback(proposalId, support, reason)` — feedback on an active proposal (during Updatable period)
- `sendCandidateFeedback(proposer, slug, support, reason)` — feedback on a candidate

Both use the same support values as voting: 0=Against, 1=For, 2=Abstain.

## Encoding Proposal Transactions

The `propose` function takes parallel arrays:

| Parameter | Type | Description |
|-----------|------|-------------|
| `targets` | address[] | Contracts to call |
| `values` | uint256[] | ETH to send with each call |
| `signatures` | string[] | Function signatures (e.g. `"transfer(address,uint256)"`) |
| `calldatas` | bytes[] | ABI-encoded function arguments |
| `description` | string | Markdown description with title on first line |

A proposal can contain up to 10 actions. All arrays must be the same length.

**Example: Transfer 10 ETH from treasury**
```
targets:    ["0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71"]
values:     [0]
signatures: ["sendETH(address,uint256)"]
calldatas:  [abi.encode(recipientAddress, 10e18)]
description: "# Transfer 10 ETH\nSend 10 ETH to recipient for project funding."
```
