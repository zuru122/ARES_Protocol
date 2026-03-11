// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IDistributor} from "../interfaces/IDistributor.sol";
import {IERC20} from "../interfaces/IERC20.sol";

contract MerkleDistributor is IDistributor {
    IERC20 private _token;
    bytes32 private _merkleRootHash;
    address private _govAddress;
    mapping(address => bool) private _claimed;

    constructor(address _tokenAddress, bytes32 _initialRootHash, address _gov) {
        _token = IERC20(_tokenAddress);
        _merkleRootHash = _initialRootHash;
        _govAddress = _gov;
    }

    function claim(address _recipient, uint256 _amount, bytes32[] calldata _proof) external {
        require(!_claimed[_recipient], "already claimed");

        bytes32 leaf = keccak256(abi.encodePacked(_recipient, _amount));
        require(_verify(_proof, _merkleRootHash, leaf), "invalid proof");

        _claimed[_recipient] = true;
        bool success = _token.transfer(_recipient, _amount);
        require(success, "transfer failed");

        emit Claimed(_recipient, _amount);
    }

    function updateRootHash(bytes32 _newRootHash) external {
        require(msg.sender == _govAddress, "only governance");
        bytes32 oldRootHash = _merkleRootHash;
        _merkleRootHash = _newRootHash;
        emit RootHashUpdated(oldRootHash, _newRootHash);
    }

    function hasClaimed(address _recipient) external view returns (bool) {
        return _claimed[_recipient];
    }

    function getMerkleRootHash() external view returns (bytes32) {
        return _merkleRootHash;
    }

    function _verify(bytes32[] calldata _proof, bytes32 _root, bytes32 _leaf) internal pure returns (bool) {
        bytes32 computedHash = _leaf;

        for (uint256 i = 0; i < _proof.length; i++) {
            bytes32 proofElement = _proof[i];

            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == _root;
    }
}
