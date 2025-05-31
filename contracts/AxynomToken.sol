// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AxynomToken
 * @notice ERC20 token with 2.5% transfer tax routed to Rewards, Treasury, and LP.
 */
contract AxynomToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public constant TAX_BPS = 250; // 2.5% = 250 basis points
    uint256 public constant MAX_BPS = 10000;

    address public rewardsPool;
    address public treasury;
    address public liquidityPool;

    mapping(address => bool) public isTaxExempt;

    event TaxDistributed(uint256 totalTax, uint256 toRewards, uint256 toTreasury, uint256 toLP);
    event TaxExemptionUpdated(address account, bool isExempt);
    event DestinationsUpdated(address rewards, address treasury, address liquidity);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address rewards,
        address treasury_,
        address liquidity
    ) public initializer {
        __ERC20_init("Axynom", "AXY");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);

        rewardsPool = rewards;
        treasury = treasury_;
        liquidityPool = liquidity;

        // Mint fixed supply to admin
        _mint(admin, 100_000_000 * 1e18);
    }

    function _authorizeUpgrade(address newImpl) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @notice Override the ERC20 _update function to apply transfer tax logic
     */
    function _update(address from, address to, uint256 amount) internal override {
        // Exempt cases (mint, burn, or tax-exempt addresses)
        if (
            from == address(0) || to == address(0) ||
            isTaxExempt[from] || isTaxExempt[to] || TAX_BPS == 0
        ) {
            super._update(from, to, amount);
            return;
        }

        uint256 tax = (amount * TAX_BPS) / MAX_BPS;
        uint256 sendAmount = amount - tax;

        // Tax splits
        uint256 toRewards = (tax * 60) / 100;
        uint256 toTreasury = (tax * 20) / 100;
        uint256 toLP = tax - toRewards - toTreasury;

        // Route taxes
        super._update(from, rewardsPool, toRewards);
        super._update(from, treasury, toTreasury);
        super._update(from, liquidityPool, toLP);

        // Send net amount to recipient
        super._update(from, to, sendAmount);

        emit TaxDistributed(tax, toRewards, toTreasury, toLP);
    }

    // ========================= Management =============================

    function setTaxDestinations(address rewards, address treasury_, address liquidity) external onlyRole(MANAGER_ROLE) {
        require(rewards != address(0) && treasury_ != address(0) && liquidity != address(0), "Zero address");
        rewardsPool = rewards;
        treasury = treasury_;
        liquidityPool = liquidity;
        emit DestinationsUpdated(rewards, treasury_, liquidity);
    }

    function setTaxExempt(address account, bool exempt) external onlyRole(MANAGER_ROLE) {
        isTaxExempt[account] = exempt;
        emit TaxExemptionUpdated(account, exempt);
    }

    // ========================= View Helpers =============================

    function taxAmount(uint256 amount) public pure returns (uint256) {
        return (amount * TAX_BPS) / MAX_BPS;
    }

    function netAmountAfterTax(uint256 amount) public pure returns (uint256) {
        return amount - taxAmount(amount);
    }
}
