// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AxynomTreasury
 * @notice Unified vault for all treasury operations: transfers, rewards, hot wallet flows, and investment logs.
 */
contract AxynomTreasury is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // ───────────────────────────────────────────────
    // 🔐 Roles
    // ───────────────────────────────────────────────
    bytes32 public constant TREASURY_MANAGER = keccak256("TREASURY_MANAGER");
    bytes32 public constant MODULE_ROLE = keccak256("MODULE_ROLE");
    bytes32 public constant REWARDS_CONSUMER_ROLE = keccak256("REWARDS_CONSUMER_ROLE");
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");

    // ───────────────────────────────────────────────
    // 📦 State
    // ───────────────────────────────────────────────
    address public daoController;
    bool public daoActivated;

    address public rewardsPool;
    address public investmentWallet;
    uint256 public monthlyWalletCap;
    mapping(uint256 => uint256) public monthlySpent;

    // ───────────────────────────────────────────────
    // 📣 Events
    // ───────────────────────────────────────────────
    event TreasuryTransfer(address indexed token, address indexed to, uint256 amount);
    event TreasuryReceived(address indexed from, uint256 amount);
    event DAOControlTransferred(address newDAO);
    event RewardsPoolSet(address pool);
    event RewardsPoolRefilled(address token, uint256 amount, address pool);
    event WalletAllocation(address indexed token, address indexed to, uint256 amount, string reason);
    event ReturnReported(address indexed token, uint256 amount, string tag);
    event InvestmentWalletSet(address wallet);
    event MonthlyWalletCapSet(uint256 cap);
    event RoleCheck(address caller, bool isManager, bool isModule, bool isDAO, bool isAuthorized);

    // ───────────────────────────────────────────────
    // 🛠️ Initialize
    // ───────────────────────────────────────────────
    function initialize(address initialAdmin) public initializer {
        require(initialAdmin != address(0), "Invalid admin");

        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(TREASURY_MANAGER, initialAdmin);

        monthlyWalletCap = 100_000e18;
    }

    // ───────────────────────────────────────────────
    // 🔁 Transfers
    // ───────────────────────────────────────────────

    function sendTo(address token, address to, uint256 amount) external whenNotPaused {
        require(to != address(0), "Invalid recipient");

        bool authorized =
            hasRole(TREASURY_MANAGER, msg.sender) ||
            hasRole(MODULE_ROLE, msg.sender) ||
            (daoActivated && msg.sender == daoController);

        require(authorized, "Not authorized");

        IERC20Upgradeable(token).safeTransfer(to, amount);
        emit TreasuryTransfer(token, to, amount);
    }

    function sendETH(address payable to, uint256 amount) external whenNotPaused {
        require(to != address(0), "Invalid ETH recipient");

        bool authorized =
            hasRole(TREASURY_MANAGER, msg.sender) ||
            hasRole(MODULE_ROLE, msg.sender) ||
            (daoActivated && msg.sender == daoController);

        require(authorized, "Not authorized");

        (bool sent, ) = to.call{value: amount}("");
        require(sent, "ETH transfer failed");

        emit TreasuryTransfer(address(0), to, amount);
    }

    function deposit(address token, uint256 amount) external {
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);
        emit TreasuryReceived(msg.sender, amount);
    }

    receive() external payable {
        emit TreasuryReceived(msg.sender, msg.value);
    }

    // ───────────────────────────────────────────────
    // 🏛️ DAO Setup
    // ───────────────────────────────────────────────

    function setDAOController(address _dao) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!daoActivated, "DAO already set");
        require(_dao != address(0), "Invalid DAO address");

        daoActivated = true;
        daoController = _dao;

        emit DAOControlTransferred(_dao);
    }

    // ───────────────────────────────────────────────
    // 🎁 Rewards
    // ───────────────────────────────────────────────

    function setRewardsPool(address pool) external onlyRole(TREASURY_MANAGER) {
        require(pool != address(0), "Invalid address");
        rewardsPool = pool;
        emit RewardsPoolSet(pool);
    }

    function refillRewardsPool(address token, uint256 amount) external whenNotPaused {
        require(hasRole(REWARDS_CONSUMER_ROLE, msg.sender), "Not authorized");
        require(token != address(0), "Invalid token");
        require(rewardsPool != address(0), "Rewards pool not set");

        IERC20Upgradeable(token).safeTransfer(rewardsPool, amount);
        emit RewardsPoolRefilled(token, amount, rewardsPool);
    }

    // ───────────────────────────────────────────────
    // 🔓 Wallet-Based Allocation (Hot Wallet)
    // ───────────────────────────────────────────────

    function setInvestmentWallet(address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(wallet != address(0), "Invalid wallet");
        investmentWallet = wallet;
        emit InvestmentWalletSet(wallet);
    }

    function setMonthlyWalletCap(uint256 cap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        monthlyWalletCap = cap;
        emit MonthlyWalletCapSet(cap);
    }

    function allocateToWallet(address token, uint256 amount, string calldata reason)
        external
        onlyRole(TREASURY_MANAGER)
    {
        require(investmentWallet != address(0), "Wallet not set");
        require(amount > 0, "Zero amount");

        uint256 currentMonth = block.timestamp / 30 days;
        monthlySpent[currentMonth] += amount;
        require(monthlySpent[currentMonth] <= monthlyWalletCap, "Over monthly cap");

        IERC20Upgradeable(token).safeTransfer(investmentWallet, amount);
        emit WalletAllocation(token, investmentWallet, amount, reason);
    }

    function getMonthlySpent() external view returns (uint256) {
        return monthlySpent[block.timestamp / 30 days];
    }

    // ───────────────────────────────────────────────
    // 🧾 Reporting & Recovery
    // ───────────────────────────────────────────────

    function reportReturn(address token, uint256 amount, string calldata tag)
        external
        onlyRole(REPORTER_ROLE)
    {
        emit ReturnReported(token, amount, tag);
    }

    function recoverStuckERC20(address token, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Invalid recipient");
        uint256 balance = IERC20Upgradeable(token).balanceOf(address(this));
        IERC20Upgradeable(token).safeTransfer(to, balance);
    }

    // ───────────────────────────────────────────────
    // 🧪 Debug
    // ───────────────────────────────────────────────

    function testAuthorization(address caller)
        external
        view
        returns (bool isManager, bool isModule, bool isDAO, bool isAuthorized, address context)
    {
        isManager = hasRole(TREASURY_MANAGER, caller);
        isModule = hasRole(MODULE_ROLE, caller);
        isDAO = (daoActivated && caller == daoController);
        isAuthorized = isManager || isModule || isDAO;
        context = address(this);
    }

    // ───────────────────────────────────────────────
    // ⛔ Emergency Controls
    // ───────────────────────────────────────────────

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ───────────────────────────────────────────────
    // 🔐 UUPS Upgrade Authorization
    // ───────────────────────────────────────────────

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
