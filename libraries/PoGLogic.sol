// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PoGLogic
/// @notice Pure logic for calculating Proof-of-Growth token rewards
library PoGLogic {
    /**
     * @notice Calculates the reward based on GP and a multiplier.
     * @dev Called from PoG.sol. Multiplier should be set to 1e18 for 1:1.
     * @param gpPoints The amount of Growth Points earned.
     * @param multiplier The reward multiplier (e.g., 2e18 = 2x).
     * @return rewardAmount Final reward to distribute in tokens.
     */
    function calculateReward(uint256 gpPoints, uint256 multiplier) internal pure returns (uint256) {
        return (gpPoints * multiplier) / 1e18;
    }
}
