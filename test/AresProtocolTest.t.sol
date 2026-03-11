// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ProposalMg} from "../src/modules/ProposalMg.sol";
import {Timelock} from "../src/modules/TimeLock.sol";
import {MerkleDistributor} from "../src/modules/MerkleDistr.sol";
import {AresProtocol} from "../src/core/AresProtocol.sol";
import {IProposalMg} from "../src/interfaces/IProposalMg.sol";
import {ITimeLock} from "../src/interfaces/ITimeLock.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract AresProtocolTest is Test {

    address constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IERC20 public usdc;

    ProposalMg public proposalMg;
    Timelock public timelock;
    MerkleDistributor public distributor;
    AresProtocol public treasury;

    address public web3Bridge; 
    address public zuru;
    address public ay;

    uint256 public signer1Key = 0xA11CE;
    uint256 public signer2Key = 0xB0B;
    address public signer1;
    address public signer2;

    bytes32 public merkleRoot;
    uint256 public zuruAmount = 100e6;

    function setUp() public {
        vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/ZE_JFcHdE8WB7w0eR_Zd3-W0zGmS74ZU");

        usdc       = IERC20(USDC_MAINNET);
        web3Bridge = makeAddr("web3Bridge");
        zuru       = makeAddr("zuru");
        ay         = makeAddr("ay");
        signer1    = vm.addr(signer1Key);
        signer2    = vm.addr(signer2Key);

        vm.startPrank(web3Bridge);

        address[] memory signers = new address[](2);
        signers[0] = signer1;
        signers[1] = signer2;

        proposalMg  = new ProposalMg(signers, 2);
        merkleRoot  = keccak256(abi.encodePacked(zuru, zuruAmount));
        treasury    = new AresProtocol(address(proposalMg), address(0), address(usdc));
        timelock    = new Timelock(address(proposalMg), address(treasury), 10_000e6);
        distributor = new MerkleDistributor(address(usdc), merkleRoot, address(treasury));

        treasury.setTimelock(address(timelock));
        vm.stopPrank();

        deal(address(usdc), address(treasury), 500_000e6);
        deal(address(usdc), address(distributor), 10_000e6);
        vm.deal(web3Bridge, 10 ether);
    }

    function test_ProposalLifecycle() public {
        bytes32 proposalId = _createProposal("lifecycle test", 1000e6);

        assertEq(
            uint256(_getStatus(proposalId)),
            uint256(IProposalMg.ProposalStatus.PENDING)
        );

        vm.warp(block.timestamp + 1 hours + 1);
        _queueProposal(proposalId);

        assertEq(
            uint256(_getStatus(proposalId)),
            uint256(IProposalMg.ProposalStatus.QUEUED)
        );

        timelock.queue(proposalId);
        vm.warp(block.timestamp + 48 hours + 1);

        uint256 before = usdc.balanceOf(zuru);
        timelock.execute(proposalId);
        assertEq(usdc.balanceOf(zuru) - before, 1000e6);

        assertEq(
            uint256(timelock.getTimelockEntry(proposalId).status),
            uint256(ITimeLock.TimeLockStatus.EXECUTED)
        );
    }

    function test_SignatureVerification() public {
        bytes32 proposalId = _createProposal("sig test", 500e6);
        vm.warp(block.timestamp + 1 hours + 1);
        _queueProposal(proposalId);
        assertEq(
            uint256(_getStatus(proposalId)),
            uint256(IProposalMg.ProposalStatus.QUEUED)
        );
    }

    function test_TimelockExecution() public {
        bytes32 proposalId = _createAndQueueToTimelock();

        assertFalse(timelock.isReadyToExecute(proposalId));
        vm.warp(block.timestamp + 48 hours + 1);
        assertTrue(timelock.isReadyToExecute(proposalId));
        timelock.execute(proposalId);

        assertEq(
            uint256(timelock.getTimelockEntry(proposalId).status),
            uint256(ITimeLock.TimeLockStatus.EXECUTED)
        );
    }

    function test_RewardClaiming() public {
        bytes32[] memory proof = new bytes32[](0);
        uint256 before = usdc.balanceOf(zuru);

        vm.prank(zuru);
        distributor.claim(zuru, zuruAmount, proof);

        assertEq(usdc.balanceOf(zuru) - before, zuruAmount);
        assertTrue(distributor.hasClaimed(zuru));
    }

    function test_RevertWhen_Reentrancy() public {
        bytes32 proposalId = _createAndQueueToTimelock();
        vm.warp(block.timestamp + 48 hours + 1);
        timelock.execute(proposalId);

        vm.expectRevert("not queued");
        timelock.execute(proposalId);
    }

    function test_RevertWhen_DoubleClaim() public {
        bytes32[] memory proof = new bytes32[](0);

        vm.prank(zuru);
        distributor.claim(zuru, zuruAmount, proof);

        vm.prank(zuru);
        vm.expectRevert("already claimed");
        distributor.claim(zuru, zuruAmount, proof);
    }

    function test_RevertWhen_InvalidSignature() public {
        bytes32 proposalId = _createProposal("invalid sig", 500e6);
        vm.warp(block.timestamp + 1 hours + 1);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 wrongKey = 0xDEAD;

        address[] memory signers    = new address[](2);
        bytes[]   memory signatures = new bytes[](2);
        uint256[] memory nonces     = new uint256[](2);

        signers[0]    = vm.addr(wrongKey);
        signers[1]    = vm.addr(wrongKey);
        signatures[0] = _signProposal(proposalId, wrongKey, 0, deadline);
        signatures[1] = _signProposal(proposalId, wrongKey, 0, deadline);

        vm.expectRevert("insufficient signatures");
        proposalMg.queueProposal(
            proposalId, signers, signatures, nonces, deadline
        );
    }

    function test_RevertWhen_PrematureExecution() public {
        bytes32 proposalId = _createAndQueueToTimelock();

        vm.expectRevert("delay not passed");
        timelock.execute(proposalId);
    }

    function test_RevertWhen_ProposalReplay() public {
        bytes32 proposalId = _createAndQueueToTimelock();
        vm.warp(block.timestamp + 48 hours + 1);
        timelock.execute(proposalId);

        vm.expectRevert("not queued");
        timelock.execute(proposalId);
    }

    function test_RevertWhen_PrematureQueue() public {
        bytes32 proposalId = _createProposal("premature queue", 500e6);

        uint256 deadline = block.timestamp + 1 hours;

        address[] memory signers    = new address[](2);
        bytes[]   memory signatures = new bytes[](2);
        uint256[] memory nonces     = new uint256[](2);

        signers[0]    = signer1;
        signers[1]    = signer2;
        signatures[0] = _signProposal(proposalId, signer1Key, 0, deadline);
        signatures[1] = _signProposal(proposalId, signer2Key, 0, deadline);

        vm.expectRevert("still in commit phase");
        proposalMg.queueProposal(
            proposalId, signers, signatures, nonces, deadline
        );
    }

    function test_RevertWhen_UnauthorizedCancel() public {
        bytes32 proposalId = _createProposal("cancel test", 500e6);

        vm.prank(ay);
        vm.expectRevert("not authorized to cancel");
        proposalMg.cancelProposal(proposalId);
    }

    function test_RevertWhen_InvalidMerkleProof() public {
        bytes32[] memory proof = new bytes32[](0);

        vm.prank(zuru);
        vm.expectRevert("invalid proof");
        distributor.claim(zuru, zuruAmount * 2, proof);
    }

    function _createProposal(
        string memory _desc,
        uint256 _amount
    ) internal returns (bytes32) {
        bytes memory data = abi.encodeWithSignature(
            "transfer(address,uint256)", zuru, _amount
        );
        vm.prank(web3Bridge);
        return proposalMg.createProposal{value: 0.1 ether}(
            address(usdc),
            data,
            0,
            _desc,
            IProposalMg.ProposalType.TRANSFER
        );
    }

    function _createAndQueueToTimelock() internal returns (bytes32) {
        bytes32 proposalId = _createProposal("timelock test", 1000e6);
        vm.warp(block.timestamp + 1 hours + 1);
        _queueProposal(proposalId);
        timelock.queue(proposalId);
        return proposalId;
    }

    function _queueProposal(bytes32 _proposalId) internal {
        uint256 deadline = block.timestamp + 1 hours;

        address[] memory signers    = new address[](2);
        bytes[]   memory signatures = new bytes[](2);
        uint256[] memory nonces     = new uint256[](2);

        signers[0]    = signer1;
        signers[1]    = signer2;
        signatures[0] = _signProposal(_proposalId, signer1Key, 0, deadline);
        signatures[1] = _signProposal(_proposalId, signer2Key, 0, deadline);

        proposalMg.queueProposal(
            _proposalId, signers, signatures, nonces, deadline
        );
    }

    function _getStatus(
        bytes32 _proposalId
    ) internal view returns (IProposalMg.ProposalStatus) {
        return proposalMg.getProposal(_proposalId).status;
    }

    function _signProposal(
        bytes32 _proposalId,
        uint256 _privKey,
        uint256 _nonce,
        uint256 _deadline
    ) internal view returns (bytes memory) {
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("ARES Protocol"),
            keccak256("1"),
            block.chainid,
            address(proposalMg)
        ));

        bytes32 structHash = keccak256(abi.encode(
            keccak256("Approval(bytes32 proposalId,address signer,uint256 nonce,uint256 deadline)"),
            _proposalId,
            vm.addr(_privKey),
            _nonce,
            _deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privKey, digest);
        return abi.encodePacked(r, s, v);
    }
}