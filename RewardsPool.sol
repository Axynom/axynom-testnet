// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title RewardsPool
 * @notice Modular token vault to hold and release rewards for staking/PoG.
 */
contract RewardsPool is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// Approved contracts allowed to send tokens here (Staking, PoG)
    mapping(address => bool) public authorizedContracts;

    event Refunded(address indexed token, uint256 amount, address to);
    event Authorized(address contractAddr, bool allowed);

    /// @notice Initialize the contract (used with proxy)
    function initialize(address admin) public initializer {
        require(admin != address(0), "Invalid admin");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);
    }

    /// @notice Authorize a contract to call receiveFromTreasury
    function authorize(address contractAddr, bool allowed) external onlyRole(MANAGER_ROLE) {
        authorizedContracts[contractAddr] = allowed;
        emit Authorized(contractAddr, allowed);
    }

    /// @notice View balance of any token held by this contract
    function getBalance(address token) external view returns (uint256) {
        return IERC20Upgradeable(token).balanceOf(address(this));
    }

    /// @notice Accept ERC20 tokens from Treasury
    function receiveFromTreasury(address token, uint256 amount) external {
        require(authorizedContracts[msg.sender], "Not authorized");
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Emergency withdrawal by manager
    function withdrawTo(address token, address to, uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(to != address(0), "Invalid address");
        IERC20Upgradeable(token).safeTransfer(to, amount);
        emit Refunded(token, amount, to);
    }

    /// @dev Required for UUPS upgradeability
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function approveConsumer(address token, address spender) external onlyRole(MANAGER_ROLE) {
    IERC20Upgradeable(token).approve(spender, type(uint256).max);
}

/// @notice Called by PoG or Staking contracts to send rewards to contributors
function distributeReward(address token, address to, uint256 amount) external {
    require(authorizedContracts[msg.sender], "Not authorized");
    require(to != address(0), "Invalid recipient");

    IERC20Upgradeable(token).safeTransfer(to, amount);
}


}
