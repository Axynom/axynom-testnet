// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library StakeLogic {
    uint256 internal constant SECONDS_IN_YEAR = 365 days;

    struct StakeInfo {
        uint256 amount;
        uint256 startTimestamp;
        uint256 lockDuration;
        uint256 apy;
        bool claimed;
    }

    function calculateReward(
        uint256 amount,
        uint256 apy,
        uint256 duration
    ) internal pure returns (uint256 reward) {
        reward = (amount * apy * duration) / (100 * SECONDS_IN_YEAR);
    }

    function getAvailableReward(
        StakeInfo memory s
    ) internal view returns (uint256) {
        if (s.claimed) return 0;
        uint256 elapsed = block.timestamp - s.startTimestamp;
        return calculateReward(s.amount, s.apy, elapsed);
    }

    function isMature(
        StakeInfo memory s
    ) internal view returns (bool) {
        return !s.claimed && block.timestamp >= s.startTimestamp + s.lockDuration;
    }
}
