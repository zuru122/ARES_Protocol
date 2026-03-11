// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IAresProtocol {
    function executeProposal(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) external returns (bool);
}