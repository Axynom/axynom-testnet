// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ContributionRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant REDEEMER_ROLE = keccak256("REDEEMER_ROLE");

    enum Status { Pending, Approved, Rejected }

    struct Contribution {
        address contributor;
        string contributionType;
        string ref;
        uint256 timestamp;
        Status status;
        uint256 pogPointsAssigned;
    }

    Contribution[] public contributions;

    mapping(string => bool) public usedRefs;
    mapping(address => uint256) public totalPoints;       // total unclaimed + redeemed
    mapping(address => uint256) public unclaimedPoints;   // GP available for redeem
    mapping(address => uint256) public lifetimePoints;    // permanent GP earned, cannot decrease

    event ContributionSubmitted(
        address indexed contributor,
        string contributionType,
        string ref,
        uint256 pogPoints,
        Status status
    );

    event ContributionRejected(uint256 indexed id);
    event PointsConsumed(address indexed user, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ------------------------------------------------------------------------
    // 🛠️ Admin Functions
    // ------------------------------------------------------------------------

    function submitForUser(
        address contributor,
        string memory _type,
        string memory _ref,
        uint256 gpPoints
    ) external onlyRole(MANAGER_ROLE) {
        require(!usedRefs[_ref], "Ref already submitted");
        require(gpPoints > 0, "GP must be positive");
        usedRefs[_ref] = true;

        contributions.push(Contribution({
            contributor: contributor,
            contributionType: _type,
            ref: _ref,
            timestamp: block.timestamp,
            status: Status.Approved,
            pogPointsAssigned: gpPoints
        }));

        totalPoints[contributor] += gpPoints;
        unclaimedPoints[contributor] += gpPoints;
        lifetimePoints[contributor] += gpPoints;

        emit ContributionSubmitted(contributor, _type, _ref, gpPoints, Status.Approved);
    }

    function rejectById(uint256 id) external onlyRole(MANAGER_ROLE) {
        require(id < contributions.length, "Invalid contribution ID");
        contributions[id].status = Status.Rejected;
        emit ContributionRejected(id);
    }

    // ------------------------------------------------------------------------
    // ✅ GP Redemption Logic (PoG Only)
    // ------------------------------------------------------------------------

    function consumePoints(address user, uint256 amount) external onlyRole(REDEEMER_ROLE) {
        require(amount > 0, "Amount must be positive");
        require(unclaimedPoints[user] >= amount, "Not enough unclaimed GP");

        unchecked {
            unclaimedPoints[user] -= amount;
        }

        emit PointsConsumed(user, amount);
    }

    // ------------------------------------------------------------------------
    // 🌐 Public Views
    // ------------------------------------------------------------------------

    function getContribution(uint256 index) external view returns (Contribution memory) {
        return contributions[index];
    }

    function totalContributions() external view returns (uint256) {
        return contributions.length;
    }

    function getContributionsByAddress(address user) external view returns (Contribution[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < contributions.length; i++) {
            if (contributions[i].contributor == user) count++;
        }

        Contribution[] memory result = new Contribution[](count);
        uint256 idx = 0;

        for (uint256 i = 0; i < contributions.length; i++) {
            if (contributions[i].contributor == user) {
                result[idx++] = contributions[i];
            }
        }

        return result;
    }
}
