// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library RewardRouter {
    using SafeERC20 for IERC20;

    /// @notice Transfers reward tokens from reward pool to user
    function sendReward(
        address token,
        address rewardsPool,
        address user,
        uint256 amount
    ) internal {
        require(token != address(0) && rewardsPool != address(0), "Invalid token or pool");
        IERC20(token).safeTransferFrom(rewardsPool, user, amount);
    }
}
