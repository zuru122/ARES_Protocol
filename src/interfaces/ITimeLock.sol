// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ITimeLock {
    enum TimeLockStatus {
        QUEUED,
        EXECUTED,
        CANCELED
    }

    struct TimelockEntry {
        bytes32 proposalId;
        uint256 executableAt;
        TimeLockStatus status;
    }

    event TimeLockQueued(bytes32 indexed proposalId, uint256 executableAt);

    event TimeLockExecuted(bytes32 indexed proposalId);

    event TimeLockCanceled(bytes32 indexed proposalId);

    function queue(bytes32 _proposalId) external;

    function execute(bytes32 _proposalId) external;

    function cancel(bytes32 _proposalId) external;

    function isReadyToExecute(bytes32 _proposalId) external view returns (bool);
}
