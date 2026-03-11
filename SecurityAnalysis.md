## ARES Protocol (Security Analysis)

### Attack Surfaces & Mitigations

#### 1. Flash Loan Attack

An attacker borrows tokens to manipulate governance in one transaction.

Snapshot system records balances at proposal creation time. Borrowed tokens don't appear in the snapshot.

```solidity
AttackGuards.recordSnapshot(_snapshot, proposalId);
```

#### 2. Signature Replay

Same signature reused on a different proposal.

Every signature includes a nonce. After use the nonce increments — old signatures are permanently invalid.

```solidity
_nonces[_signers[i]]++;
```

#### 3. Cross-Chain Replay

Valid signature from mainnet reused on another chain.

Domain separator includes `block.chainid` and `address(this)`. Different chain = different domain = invalid signature.

```solidity
block.chainid,
address(this)
```

#### 4. Reentrancy

Malicious contract calls `execute()` again mid-execution.

Two defenses — `nonReentrant` modifier + status updated to `EXECUTED` before external call.

```solidity
entry.status = TimeLockStatus.EXECUTED; // before external call
IAresProtocol(_treasury).executeProposal(...);
```

#### 5. Treasury Drain

Single proposal tries to drain everything at once.

Rate limiter caps total withdrawals per 24 hours across all proposals.

```solidity
require(_self.spentToday + _amount <= _self.maxDailyLimit, "daily limit exceeded");
```

#### 6. Proposal Griefing

Attacker spams fake proposals to clog the queue.

Every proposal requires 0.1 ETH deposit. Governance can slash it if the proposal is malicious.

#### 7. Double Claim

Contributor calls `claim()` more than once.

**Fix:** `_claimed` mapping permanently blocks second attempts.

```solidity
require(!_claimed[_recipient], "already claimed");
_claimed[_recipient] = true;
```

#### 8. Premature Execution

Someone tries to execute before the 48hr delay.

`executableAt` check strictly enforced.

```solidity
require(block.timestamp >= entry.executableAt, "delay not passed");
```
