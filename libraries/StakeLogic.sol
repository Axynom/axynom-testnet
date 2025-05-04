// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library StakeLogic {
    uint256 internal constant SECONDS_IN_YEAR = 365 days;

    function calculateReward(
        uint256 amount,
        uint256 apy,
        uint256 duration
    ) internal pure returns (uint256 reward) {
        reward = (amount * apy * duration) / (100 * SECONDS_IN_YEAR);
    }

    /// @notice Applies a 10% bonus if stake is being re-staked after maturity
    function applyReStakeBonus(uint256 baseReward) internal pure returns (uint256) {
        return baseReward + (baseReward * 10) / 100;
    }

    function hasCompletedStake(uint256 startTimestamp, uint256 duration) internal view returns (bool) {
        return block.timestamp >= startTimestamp + duration;
    }
}
