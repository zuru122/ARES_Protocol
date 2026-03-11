// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "../interfaces/IERC20.sol";
import {IDistributor} from "../interfaces/IDistributor.sol";
import {IProposalMg} from "../interfaces/IProposalMg.sol";
import {ITimeLock} from "../interfaces/ITimeLock.sol";

contract AresProtocol {

    IProposalMg public proposalManager;
    ITimeLock public timeLock;
    IDistributor public distributor;
    IERC20 public governanceToken;
    address public owner;
    bool private _timelockSet;

    event Executed(address indexed target, uint256 value, bytes data);
    event Deposited(address indexed sender, uint256 amount);
    event TokenDeposited(address indexed sender, uint256 amount);
    event TimelockSet(address indexed timelockAddr);

    modifier onlyTimelock() {
        require(msg.sender == address(timeLock), "only timelock");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor(
        address _proposalManagerAddr,
        address _distributorAddr,
        address _tokenAddr
    ) {
        proposalManager = IProposalMg(_proposalManagerAddr);
        distributor = IDistributor(_distributorAddr);
        governanceToken = IERC20(_tokenAddr);
        owner = msg.sender;
    }

    function setTimelock(address _timelockAddr) external onlyOwner {
        require(!_timelockSet, "timelock already set");
        require(_timelockAddr != address(0), "invalid address");
        timeLock = ITimeLock(_timelockAddr);
        _timelockSet = true;
        emit TimelockSet(_timelockAddr);
    }

    function executeProposal(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) external onlyTimelock returns (bool) {
        require(_target != address(0), "invalid target");

        (bool success, ) = _target.call{value: _value}(_data);
        require(success, "execution failed");

        emit Executed(_target, _value, _data);
        return success;
    }

    function depositToken(uint256 _amount) external {
        require(_amount > 0, "amount must be greater than 0");
        require(
            governanceToken.transferFrom(msg.sender, address(this), _amount),
            "transfer failed"
        );
        emit TokenDeposited(msg.sender, _amount);
    }

    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function getTokenBalance() external view returns (uint256) {
        return governanceToken.balanceOf(address(this));
    }

    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }
}