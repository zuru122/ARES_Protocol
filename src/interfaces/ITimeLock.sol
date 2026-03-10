// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ITimeLock {
    
    enum TimeLockStatus {
        QUEUED,
        EXECUTED,
        CANCELED
    }

    struct TimeLocked {
        bytes32 proposalId;
        uint256 startAt;
        TimeLockStatus status;
    }

    event TimeLockQueued(bytes32 indexed proposalId, uint256 startAt);

    event TimeLockExecuted(bytes32 indexed proposalId);

    event TimeLockCanceled(bytes32 indexed proposalId);

    function getTimestamp(bytes32 proposalId) external view returns (uint256);

    function queue(bytes32 proposalId) external;

    function execute(bytes32 proposalId) external;

    function cancel(bytes32 proposalId) external;

    function getTimeLockStatus(bytes32 proposalId) external view returns (TimeLocked memory);

    function isReadyToExecute(bytes32 proposalId) external view returns (bool);
}
