// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

library PoolInteractions {
    function sendReward(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        require(to != address(0), "Invalid recipient");
        IERC20Upgradeable(tokenAddress).transfer(to, amount);
    }

    // Placeholder for future multi-token support
    function sendStablecoinReward(address stableToken, address to, uint256 amount) internal {
        require(to != address(0), "Invalid recipient");
        IERC20Upgradeable(stableToken).transfer(to, amount);
    }
}
