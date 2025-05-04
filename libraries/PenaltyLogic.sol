// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library PenaltyLogic {
    function getPenaltyPercent(uint256 timeElapsed, uint256 totalDuration) internal pure returns (uint256) {
        if (timeElapsed >= totalDuration) {
            return 0;
        } else if (timeElapsed < (totalDuration * 66) / 100) {
            return 50;
        } else {
            return 34;
        }
    }
}
