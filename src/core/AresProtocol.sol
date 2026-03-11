// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "../interfaces/IERC20.sol";
import "../interfaces/IDistributor.sol";
import "../interfaces/IProposalMg.sol";
import "../interfaces/ITimeLock.sol";

contract AresProtocol {
    IProposalMg public proposalManager;
    ITimeLock public timeLock;
    IDistributor public distributor;

    constructor(address _proposalManager, address _timeLock, address _distributor) {
        proposalManager = IProposalMg(_proposalManager);
        timeLock = ITimeLock(_timeLock);
        distributor = IDistributor(_distributor);
    }
}
