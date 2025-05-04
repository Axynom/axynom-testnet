
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../libraries/PoGLogic.sol";

interface IContributionRegistry {
    function totalPoints(address user) external view returns (uint256);
}

interface IRewardsPool {
    function distributeReward(address token, address to, uint256 amount) external;
}

contract PoG is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // ────────────── MUST PRESERVE ORDER ──────────────
    IContributionRegistry public contributionRegistry;
    IRewardsPool public rewardsPool;
    address public rewardToken;
    uint256 public rewardMultiplier;
    mapping(address => uint256) public gpClaimed;

    // ────────────── APPENDED SAFELY ──────────────
    mapping(address => uint256) public unredeemedGP;

    // ────────────── EVENTS ──────────────
    event GPGranted(address indexed user, uint256 amount);
    event GPBurned(address indexed user, uint256 amount);
    event GPRedeemed(address indexed user, uint256 gpAmount, uint256 rewardAmount);
    event MultiplierUpdated(uint256 newMultiplier);

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

    function grantGP(address user, uint256 amount) external onlyRole(MANAGER_ROLE) {
        gpClaimed[user] += amount;
        unredeemedGP[user] += amount;
        emit GPGranted(user, amount);
    }

    function burnUnredeemedGP(address user, uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(unredeemedGP[user] >= amount, "Insufficient GP");
        unredeemedGP[user] -= amount;
        emit GPBurned(user, amount);
    }

    function redeemGP(uint256 amount) external {
        require(unredeemedGP[msg.sender] >= amount, "Not enough GP");
        unredeemedGP[msg.sender] -= amount;

        uint256 reward = PoGLogic.calculateReward(amount, rewardMultiplier);
        rewardsPool.distributeReward(rewardToken, msg.sender, reward);

        emit GPRedeemed(msg.sender, amount, reward);
    }

    function setMultiplier(uint256 _multiplier) external onlyRole(MANAGER_ROLE) {
        rewardMultiplier = _multiplier;
        emit MultiplierUpdated(_multiplier);
    }

    function getGPStats(address user) external view returns (uint256 lifetime, uint256 unredeemed) {
        return (gpClaimed[user], unredeemedGP[user]);
    }

    function _authorizeUpgrade(address newImpl) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
