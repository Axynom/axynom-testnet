// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PoolInteractions {
    function sendReward(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        require(to != address(0), "Invalid recipient");
        IERC20(tokenAddress).transfer(to, amount);
    }

    // Placeholder for future multi-token support
    function sendStablecoinReward(address stableToken, address to, uint256 amount) internal {
        require(to != address(0), "Invalid recipient");
        IERC20(stableToken).transfer(to, amount);
    }
}
