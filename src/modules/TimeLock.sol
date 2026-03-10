// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ITimeLock} from "../interfaces/ITimeLock.sol";
import {IProposalMg} from "../interfaces/IProposalMg.sol";
import {AttackGuards} from "../libraries/AttackGuards.sol";

contract Timelock is ITimeLock {
    mapping(bytes32 => TimelockEntry) private _entries;

    IProposalMg private _proposalMg;
    address private _treasury;

    uint256 public constant TIMELOCK_DELAY = 48 hours;

    bool private _locked;

    AttackGuards.RateLimit private _rateLimit;

    modifier nonReentrant() {
        require(!_locked, "reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address _proposalMgAddr, address _treasuryAddr, uint256 _maxDailyLimit) {
        _proposalMg = IProposalMg(_proposalMgAddr);
        _treasury = _treasuryAddr;

        _rateLimit.maxDailyLimit = _maxDailyLimit;
        _rateLimit.windowStart = block.timestamp;
        _rateLimit.spentToday = 0;
    }

    function queue(bytes32 _proposalId) external {
        IProposalMg.Proposal memory proposal = _proposalMg.getProposal(_proposalId);

        require(proposal.timeCreated != 0, "proposal does not exist");

        require(proposal.status == IProposalMg.ProposalStatus.QUEUED, "proposal not queued");

        require(_entries[_proposalId].executableAt == 0, "already in timelock");

        _entries[_proposalId] = TimelockEntry({
            proposalId: _proposalId, executableAt: block.timestamp + TIMELOCK_DELAY, status: TimeLockStatus.QUEUED
        });

        emit TimeLockQueued(_proposalId, block.timestamp + TIMELOCK_DELAY);
    }

    function execute(bytes32 _proposalId) external nonReentrant {
        TimelockEntry storage entry = _entries[_proposalId];

        require(entry.executableAt != 0, "entry does not exist");
        require(entry.status == TimeLockStatus.QUEUED, "not queued");
        require(block.timestamp >= entry.executableAt, "delay not passed");

        IProposalMg.Proposal memory proposal = _proposalMg.getProposal(_proposalId);

        AttackGuards.enforceDailyLimit(_rateLimit, proposal.value);

        entry.status = TimeLockStatus.EXECUTED;

        (bool success,) = _treasury.call{value: proposal.value}(proposal.data);
        require(success, "execution failed");

        emit TimeLockExecuted(_proposalId);
    }

    function cancel(bytes32 _proposalId) external {
        TimelockEntry storage entry = _entries[_proposalId];

        require(entry.executableAt != 0, "entry does not exist");
        require(entry.status == TimeLockStatus.QUEUED, "not queued");

        entry.status = TimeLockStatus.CANCELED;

        emit TimeLockCanceled(_proposalId);
    }

    function getTimelockEntry(bytes32 _proposalId) external view returns (TimelockEntry memory) {
        require(_entries[_proposalId].executableAt != 0, "entry does not exist");
        return _entries[_proposalId];
    }

    function isReadyToExecute(bytes32 _proposalId) external view returns (bool) {
        TimelockEntry storage entry = _entries[_proposalId];
        return entry.executableAt != 0 && entry.status == TimeLockStatus.QUEUED && block.timestamp >= entry.executableAt;
    }
}
