// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title TreasuryInvestments
 * @notice UUPS-upgradeable module for AxynomTreasury to initiate and track external investments.
 */
interface IAxynomTreasury {
    function sendTo(address token, address to, uint256 amount) external;
}

contract TreasuryInvestments is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IAxynomTreasury public treasury;

    struct Investment {
        uint256 id;
        address protocol;
        address token;
        uint256 amount;
        uint256 timestamp;
        bool active;
        string reason;
    }

    uint256 public nextInvestmentId;
    mapping(uint256 => Investment) public investments;

    event InvestmentMade(
        uint256 indexed id,
        address indexed protocol,
        address indexed token,
        uint256 amount,
        string reason
    );

    event InvestmentReturned(
        uint256 indexed id,
        uint256 returnedAmount,
        int256 gainOrLoss
    );

    // ───────────────────────────────────────────────
    // 🧱 Initialization
    // ───────────────────────────────────────────────
    function initialize(address _treasury, address _admin) public initializer {
        require(_treasury != address(0), "Invalid treasury");
        require(_admin != address(0), "Invalid admin");

        __AccessControl_init();
        __UUPSUpgradeable_init();

        treasury = IAxynomTreasury(_treasury);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MANAGER_ROLE, _admin);
    }

    // ───────────────────────────────────────────────
    // 🔁 Investment Flow
    // ───────────────────────────────────────────────

    /**
     * @notice Triggers an investment by transferring funds via the AxynomTreasury
     */
    function invest(address token, address protocol, uint256 amount, string calldata reason)
        external
        onlyRole(MANAGER_ROLE)
    {
        require(token != address(0) && protocol != address(0), "Zero address");
        require(amount > 0, "Amount must be > 0");

        treasury.sendTo(token, protocol, amount);

        investments[nextInvestmentId] = Investment({
            id: nextInvestmentId,
            protocol: protocol,
            token: token,
            amount: amount,
            timestamp: block.timestamp,
            active: true,
            reason: reason
        });

        emit InvestmentMade(nextInvestmentId, protocol, token, amount, reason);
        nextInvestmentId++;
    }

    /**
     * @notice Called by manager after investment returns, marking result and gain/loss
     */
    function markAsReturned(uint256 id, uint256 returnedAmount)
        external
        onlyRole(MANAGER_ROLE)
    {
        Investment storage inv = investments[id];
        require(inv.active, "Already returned or invalid");

        inv.active = false;

        int256 delta = int256(returnedAmount) - int256(inv.amount);
        emit InvestmentReturned(id, returnedAmount, delta);
    }

    function getActiveInvestments() external view returns (Investment[] memory active) {
        uint256 count;
        for (uint256 i = 0; i < nextInvestmentId; i++) {
            if (investments[i].active) count++;
        }

        active = new Investment[](count);
        uint256 j;
        for (uint256 i = 0; i < nextInvestmentId; i++) {
            if (investments[i].active) {
                active[j++] = investments[i];
            }
        }
    }

    function getAllInvestments() external view returns (Investment[] memory all) {
        all = new Investment[](nextInvestmentId);
        for (uint256 i = 0; i < nextInvestmentId; i++) {
            all[i] = investments[i];
        }
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
