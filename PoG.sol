// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../libraries/PoGLogic.sol";

interface IContributionRegistry {
    function unclaimedPoints(address user) external view returns (uint256);
    function consumePoints(address user, uint256 amount) external;
    function grantRole(bytes32 role, address account) external;
}

interface IRewardsPool {
    function distributeReward(address token, address to, uint256 amount) external;
}

contract PoG is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IContributionRegistry public contributionRegistry;
    IRewardsPool public rewardsPool;
    address public rewardToken;
    uint256 public rewardMultiplier;

    event GPRedeemed(address indexed user, uint256 gpAmount, uint256 rewardAmount);
    event MultiplierUpdated(uint256 newMultiplier);

    // ------------------------------------------------------------------------
    // ⚙️ Initializer
    // ------------------------------------------------------------------------

    function initialize(
        address _registry,
        address _pool,
        address _token,
        uint256 _multiplier
    ) public initializer {
        require(_registry != address(0) && _pool != address(0) && _token != address(0), "Invalid addresses");

        __AccessControl_init();
        __UUPSUpgradeable_init();

        contributionRegistry = IContributionRegistry(_registry);
        rewardsPool = IRewardsPool(_pool);
        rewardToken = _token;
        rewardMultiplier = _multiplier;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    // ------------------------------------------------------------------------
    // 🪙 GP Redemption
    // ------------------------------------------------------------------------

    function redeemGP(uint256 amount) external {
        require(amount > 0, "Amount must be positive");

        uint256 available = contributionRegistry.unclaimedPoints(msg.sender);
        require(available >= amount, "Not enough GP");

        // Secure GP burn
        contributionRegistry.consumePoints(msg.sender, amount);

        // Calculate and distribute reward
        uint256 reward = PoGLogic.calculateReward(amount, rewardMultiplier);
        rewardsPool.distributeReward(rewardToken, msg.sender, reward);

        emit GPRedeemed(msg.sender, amount, reward);
    }

    function estimateReward(uint256 amount) external view returns (uint256) {
        return PoGLogic.calculateReward(amount, rewardMultiplier);
    }

    // ------------------------------------------------------------------------
    // 🛠️ Admin Functions
    // ------------------------------------------------------------------------

    function setMultiplier(uint256 _multiplier) external onlyRole(MANAGER_ROLE) {
        rewardMultiplier = _multiplier;
        emit MultiplierUpdated(_multiplier);
    }

    function grantRedeemerRole() external onlyRole(DEFAULT_ADMIN_ROLE) {
        contributionRegistry.grantRole(
            keccak256("REDEEMER_ROLE"),
            address(this)
        );
    }

    function _authorizeUpgrade(address newImpl) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
