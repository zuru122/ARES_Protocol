// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IProposalMg {

    enum ProposalType {
        TRANSFER,
        CALL,
        UPGRADE
    }

    //Handles the status of a proposal state. 
    enum ProposalStatus {
        QUEUED,
        EXECUTED,
        CANCELED
    }

    struct Proposal {
        bytes32 proposalId;
        address targetAddr;
        bytes data;
        uint256 value;
        address proposerAddr;
        uint256 timeCreated;        
        string description;
        ProposalStatus status;
        ProposalType proposalType;
    }

    event ProposalCreated(
        bytes32 indexed proposalId,
        address indexed proposerAddr,
        address indexed targetAddr,
        uint256 value,
        string description,
        ProposalType proposalType
    );

    event ProposalExecuted(bytes32 indexed proposalId);

    event ProposalCanceled(bytes32 indexed proposalId);

    event ProposalQueued(bytes32 indexed proposalId);

    function createProposal(
        address targetAddr,
        bytes calldata data,
        uint256 value,
        string calldata description,
        ProposalType proposalType
    ) external returns (bytes32);

    function getProposal(bytes32 proposalId) external view returns(Proposal memory);

    function cancelProposal(bytes32 proposalId) external;   

    function queueProposal(bytes32 proposalId) external;

    function isReadyToQueue(bytes32 proposalId) external view returns (bool);  
   
}
