// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library StakingUtils {
    function getPeriodFromDuration(uint256 duration) internal pure returns (uint8) {
        if (duration == 180 days) return 0; // SIX_MONTHS
        if (duration == 365 days) return 1; // ONE_YEAR
        if (duration == 730 days) return 2; // TWO_YEARS
        revert("StakingUtils: Unknown duration");
    }
}
