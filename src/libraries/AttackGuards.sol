// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

library AttackGuards {

    struct RateLimit {
        uint256 windowStart;    
        uint256 spentToday;    
        uint256 maxDailyLimit; 
    }

    function enforceDailyLimit(
        RateLimit storage _self,
        uint256 _amount
    ) internal {
        // check if 24 hours have passed, reset the window omo...
        if (block.timestamp > _self.windowStart + 1 days) {
            _self.windowStart = block.timestamp;
            _self.spentToday = 0;
        }

        require(
            _self.spentToday + _amount <= _self.maxDailyLimit,
            "daily limit exceeded"
        );

        _self.spentToday += _amount;
    }

    function isWithinDailyLimit(
        RateLimit storage _self,
        uint256 _amount
    ) internal view returns (bool) {
        // If window has reset, full limit is available
        if (block.timestamp > _self.windowStart + 1 days) {
            return _amount <= _self.maxDailyLimit;
        }
        return _self.spentToday + _amount <= _self.maxDailyLimit;
    }

    struct Snapshot {
  
        mapping(bytes32 => uint256) proposalBlock;

        mapping(address => mapping(uint256 => uint256)) balanceAt;
    }

    function recordSnapshot(
        Snapshot storage _self,
        bytes32 _proposalId
    ) internal {
        _self.proposalBlock[_proposalId] = block.number;
    }

    function recordBalance(
        Snapshot storage _self,
        address _user,
        uint256 _balance
    ) internal {
        _self.balanceAt[_user][block.number] = _balance;
    }


    function getVotingPower(
        Snapshot storage _self,
        address _user,
        bytes32 _proposalId
    ) internal view returns (uint256) {
        uint256 snapshotBlock = _self.proposalBlock[_proposalId];
        return _self.balanceAt[_user][snapshotBlock];
    }
}