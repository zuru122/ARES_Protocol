## Architecture

### System Architecture:

Ares is a treasury system where no funds move without passing through a strict check or pipeline. Every action start as a proposal and then moves it's way through execution, but before that, it must have survived multiple checks.

<!-- Flow -->

```
USER -> ProposalMg (stores the proposal, enforces commit phase) -> signatureAuth (checks for M-of-N signers must approve) -> Timelock (48 hour delay, rate limit check) -> AresProtocol (holds funds, makes the actual call) -> Target Contract (receives the treasury action)

```

In this flow, no step can be skipped.

### Module Seperation

**ProposalMg** manages the proposal lifecycle. It stores proposals, enforces the 1-hour commit phase, verifies signatures, and tracks proposal states from PENDING to QUEUED. It does not hold funds and does not execute anything.

**Timelock** enforces the 48-hour delay. It receives queued proposals, starts the countdown, and triggers execution after the delay passes. It does not store proposal data.It reads from ProposalMg. It does not move funds directly, its calls AresProtocol.

**MerkleDistributor** handles contributor rewards independently. It verifies Merkle proofs and sends tokens to claimants. It has no connection to the proposal system, it operates on its own.

**AresProtocol** is the treasury vault. It holds all funds and is the only contract that makes external calls. It does not know anything about proposals or signatures, it only checks that the caller is the registered timelock.

**SignatureAuth** is a library that handles EIP-712 signature verification. It has no storage of its own, it is pure logic used by ProposalMg.
AttackGuards is a library that provides the rate limiter and snapshot system. It has no storage of its own state is owned by the contracts that use it.

### Security Boundaries

Below are my security boundaries

```
Who can propose?
Anyone with 0.1 ETH deposit

Who can authorize a proposal?
Only registered authorized signers

Who can queue a proposal?
Anyone, but only after commit phase + valid signatures

Who can execute?
Anyone, but only after 48hr delay passes

Who can cancel?
Original proposer or authorized signer only

Who can call AresProtocol.executeProposal?
Only the registered Timelock (onlyTimelock)

Who can update the Merkle root?
Only AresProtocol treasury address

Who can set the timelock address?
Only the deployer, once (onlyOwner + _timelockSet flag)
```

#### Trust Assumptions

Signer keys are secure: if a signer's private key is compromised the attacker can authorize malicious proposals. The rate limiter reduces damage but cannot fully stop an authorized signer.

Deployer is honest: the owner sets the timelock address once at deployment. A malicious deployer could point it to a fake timelock. After setTimelock is called it cannot be changed.

block.timestamp is approximately accurate: the commit phase and timelock delay both rely on timestamps. Miners can manipulate this by about 15 seconds which is too small to matter against 1-hour and 48-hour delays.

USDC behaves normally: the treasury holds USDC which Circle controls. Circle can pause transfers or blacklist addresses. This is outside the protocol's control.
