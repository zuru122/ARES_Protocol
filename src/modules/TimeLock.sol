// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ITimeLock} from "../interfaces/ITimeLock.sol";
import {IProposalMg} from "../interfaces/IProposalMg.sol";
import {AttackGuards} from "./AttackGuards.sol";

contract TimeLock is ITimeLock, AttackGuards {
    mapping(bytes32 => TimeLocked) public timeLocks;

    IProposalMg private _proposalMg;

    address private _treasury;

    uint256 public constant TIMELOCK_DELAY = 48 hours;

    

}
