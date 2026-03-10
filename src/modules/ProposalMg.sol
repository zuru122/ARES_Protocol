// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IProposalMg} from "../interfaces/IProposalMg.sol";
import {AttackGuards} from "../libraries/AttackGuards.sol";
import {SignatureAuth} from "../libraries/SignatureAuth.sol";

contract ProposalMg is IProposalMg {

    mapping(bytes32 => Proposal) public proposals;
    mapping(address => uint256) private _nonces;
    mapping(address => bool) private _authorizedSigners;
    mapping(bytes32 => uint256) private _deposits;

    uint256 private _threshold;

    uint256 public constant COMMIT_DELAY = 1 hours;
    uint256 public constant PROPOSAL_DEPOSIT = 0.1 ether;

    constructor(address[] memory _signers, uint256 _thresh) {
        require(_thresh > 0, "threshold cannot be zero");
        require(_thresh <= _signers.length, "threshold exceeds signers");

        for (uint256 i = 0; i < _signers.length; i++) {
            _authorizedSigners[_signers[i]] = true;
        }
        _threshold = _thresh;
    }

    function createProposal(
        address _targetAddr,
        bytes calldata _data,
        uint256 _value,
        string calldata _description,
        ProposalType _proposalType
    ) external payable returns (bytes32) {
   
        require(msg.value >= PROPOSAL_DEPOSIT, "insufficient deposit");

        bytes32 proposalId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            _targetAddr,
            _data,
            _value,
            _description,
            _proposalType
        ));

        require(proposals[proposalId].timeCreated == 0, "proposal already exists");

        _deposits[proposalId] = msg.value;

        proposals[proposalId] = Proposal({
            proposalId: proposalId,
            targetAddr: _targetAddr,
            data: _data,
            value: _value,
            proposerAddr: msg.sender,
            timeCreated: block.timestamp,
            description: _description,
            status: ProposalStatus.PENDING,
            proposalType: _proposalType
        });

        emit ProposalCreated(
            proposalId,
            msg.sender,
            _targetAddr,
            _value,
            _description,
            _proposalType
        );

        return proposalId;
    }

    function queueProposal(bytes32 _proposalId) external {
    
        require(proposals[_proposalId].timeCreated != 0, "proposal does not exist");

        Proposal storage proposal = proposals[_proposalId];

        require(proposal.status == ProposalStatus.PENDING, "proposal is not pending");

        require(
            block.timestamp >= proposal.timeCreated + COMMIT_DELAY,
            "still in commit phase"
        );

        proposal.status = ProposalStatus.QUEUED;

        emit ProposalQueued(_proposalId);
    }

    function cancelProposal(bytes32 _proposalId) external {
 
        require(proposals[_proposalId].timeCreated != 0, "proposal does not exist");

        Proposal storage proposal = proposals[_proposalId];

        require(
            proposal.status == ProposalStatus.PENDING ||
            proposal.status == ProposalStatus.QUEUED,
            "proposal cannot be cancelled"
        );

        require(
            proposal.proposerAddr == msg.sender || _authorizedSigners[msg.sender],
            "not authorized to cancel"
        );

        proposal.status = ProposalStatus.CANCELED;

        uint256 deposit = _deposits[_proposalId];
        delete _deposits[_proposalId];
        (bool success, ) = payable(proposal.proposerAddr).call{value: deposit}("");
        require(success, "refund failed");

        emit ProposalCanceled(_proposalId);
    }

    function getProposal(bytes32 _proposalId) 
        external 
        view 
        returns (Proposal memory) 
    {
        require(proposals[_proposalId].timeCreated != 0, "proposal does not exist");
        return proposals[_proposalId];
    }

    function isReadyToQueue(bytes32 _proposalId) external view returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.timeCreated != 0, "proposal does not exist");
        return block.timestamp >= proposal.timeCreated + COMMIT_DELAY;
    }
}