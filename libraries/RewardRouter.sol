// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

library RewardRouter {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice Transfers reward tokens from reward pool to user
    function sendReward(
        address token,
        address rewardsPool,
        address user,
        uint256 amount
    ) internal {
        require(token != address(0) && rewardsPool != address(0), "Invalid token or pool");
        IERC20Upgradeable(token).safeTransferFrom(rewardsPool, user, amount);
    }
}
