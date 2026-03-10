// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IDistributor {

    event Claimed(address indexed recipient, uint256 amount);
    event RootHashUpdated(bytes32 indexed oldRootHash, bytes32 indexed newRootHash);

    function updateRootHash(bytes32 _newRootHash) external;


    function claim(address _recipient, uint256 _amount, bytes32[] calldata proof) external;

    function hasClaimed(address _recipient) external view returns (bool);
    
    function getMerkleRootHash() external view returns (bytes32);
}