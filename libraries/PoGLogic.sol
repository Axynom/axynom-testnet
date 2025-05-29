// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PoGLogic
/// @notice Pure logic for calculating Proof-of-Growth token rewards
library PoGLogic {
    /**
     * @notice Calculates the reward based on GP and a multiplier.
     * @dev Multiplier should be set to 1e18 for 1:1 GP:Token ratio (e.g. 10 GP → 10e18 tokens).
     * @param gpPoints The amount of Growth Points earned (integer units).
     * @param multiplier The reward multiplier (e.g., 1e18 = 1 AXY per 1 GP).
     * @return rewardAmount Final reward to distribute in token's smallest unit.
     */
    function calculateReward(uint256 gpPoints, uint256 multiplier) internal pure returns (uint256) {
        return gpPoints * multiplier;
    }
}
