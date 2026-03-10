// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IDistributor {
    struct Distribution {
        address recipient;
        uint256 amount;
        bool hasClaimed;
    }

    event DistributionExecuted(address indexed recipient, uint256 amount);


    function distribute(Distribution[] calldata distributions) external;
}