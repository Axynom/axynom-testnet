
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./libraries/PenaltyLogic.sol";
import "./libraries/StakeLogic.sol";
import "./libraries/PoolInteractions.sol";

contract AxynomStaking is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using StakeLogic for uint256;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IERC20Upgradeable public axynomToken;
    address public rewardsPool;
    address public treasury;

    enum LockPeriod { SIX_MONTHS, ONE_YEAR, TWO_YEARS }

    struct StakeInfo {
        uint256 amount;
        uint256 startTimestamp;
        uint256 lockDuration;
        uint256 apy;
        bool claimed;
    }

    mapping(address => StakeInfo[]) public userStakes;
    mapping(LockPeriod => uint256) public capPerTier;
    mapping(LockPeriod => uint256) public totalStakedPerTier;

    uint256 public rewardDebt;
    bool public paused;

    modifier notPaused() {
        require(!paused, "Staking is paused");
        _;
    }

    event Staked(address indexed user, uint256 amount, LockPeriod period, uint256 apy);
    event Unstaked(address indexed user, uint256 amount, uint256 reward, uint256 penalty);
    event ContinuedStake(address indexed user, uint256 index, uint256 newAmount, uint256 bonusApy);
    event RewardsPoolUpdated(address pool);
    event TreasuryUpdated(address treasury);
    event StakingCapUpdated(LockPeriod indexed period, uint256 newCap);
    event RefillRequested(address indexed token, uint256 missingAmount);
    event Paused();
    event Unpaused();

    function initialize(address _token, address _rewardsPool) public initializer {
        require(_token != address(0), "Invalid token address");
        require(_rewardsPool != address(0), "Invalid rewards pool");

        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        axynomToken = IERC20Upgradeable(_token);
        rewardsPool = _rewardsPool;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    function stake(uint256 _amount, LockPeriod _period) external notPaused nonReentrant {
        require(_amount > 0, "Cannot stake 0");

        (uint256 lockDuration, uint256 apy) = getLockParams(_period);
        require(totalStakedPerTier[_period] + _amount <= capPerTier[_period], "Staking cap exceeded");

        totalStakedPerTier[_period] += _amount;
        axynomToken.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 estimatedReward = StakeLogic.calculateReward(_amount, apy, lockDuration);
        rewardDebt += estimatedReward;

        userStakes[msg.sender].push(StakeInfo({
            amount: _amount,
            startTimestamp: block.timestamp,
            lockDuration: lockDuration,
            apy: apy,
            claimed: false
        }));

        emit Staked(msg.sender, _amount, _period, apy);
    }

    function unstake(uint256 index) external notPaused nonReentrant {
        require(index < userStakes[msg.sender].length, "Invalid index");

        StakeInfo storage userStake = userStakes[msg.sender][index];
        require(!userStake.claimed, "Already claimed");

        uint256 elapsed = block.timestamp - userStake.startTimestamp;
        uint256 reward = StakeLogic.calculateReward(userStake.amount, userStake.apy, elapsed);
        uint256 penalty = (reward * PenaltyLogic.getPenaltyPercent(elapsed, userStake.lockDuration)) / 100;

        rewardDebt -= reward;
        userStake.claimed = true;

        if (penalty > 0 && treasury != address(0)) {
            PoolInteractions.sendReward(address(axynomToken), treasury, penalty);
        }

        PoolInteractions.sendReward(address(axynomToken), msg.sender, userStake.amount + (reward - penalty));
        emit Unstaked(msg.sender, userStake.amount, reward - penalty, penalty);
    }

    function continueStake(uint256 index) external notPaused nonReentrant {
        require(index < userStakes[msg.sender].length, "Invalid index");
        StakeInfo storage userStake = userStakes[msg.sender][index];
        require(!userStake.claimed, "Already claimed");
        require(block.timestamp >= userStake.startTimestamp + userStake.lockDuration, "Stake not matured");

        uint256 reward = StakeLogic.calculateReward(userStake.amount, userStake.apy, userStake.lockDuration);
        rewardDebt -= reward;
        userStake.claimed = true;

        uint256 bonusApy = (userStake.apy * 110) / 100;
        uint256 newAmount = userStake.amount + reward;
        uint256 newReward = StakeLogic.calculateReward(newAmount, bonusApy, userStake.lockDuration);
        rewardDebt += newReward;

        userStakes[msg.sender].push(StakeInfo({
            amount: newAmount,
            startTimestamp: block.timestamp,
            lockDuration: userStake.lockDuration,
            apy: bonusApy,
            claimed: false
        }));

        emit ContinuedStake(msg.sender, index, newAmount, bonusApy);
    }

    function getLockParams(LockPeriod _period) internal pure returns (uint256 duration, uint256 apy) {
        if (_period == LockPeriod.SIX_MONTHS) return (180 days, 5);
        if (_period == LockPeriod.ONE_YEAR) return (365 days, 12);
        if (_period == LockPeriod.TWO_YEARS) return (730 days, 30);
        revert("Invalid lock period");
    }

    function setCap(LockPeriod _period, uint256 _cap) external onlyRole(MANAGER_ROLE) {
        capPerTier[_period] = _cap;
        emit StakingCapUpdated(_period, _cap);
    }

    function setRewardsPool(address _new) external onlyRole(MANAGER_ROLE) {
        require(_new != address(0), "Invalid address");
        rewardsPool = _new;
        emit RewardsPoolUpdated(_new);
    }

    function setTreasury(address _treasury) external onlyRole(MANAGER_ROLE) {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function setToken(address newToken) external onlyRole(MANAGER_ROLE) {
        require(newToken != address(0), "Invalid token");
        axynomToken = IERC20Upgradeable(newToken);
    }

    function pause() external onlyRole(MANAGER_ROLE) {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyRole(MANAGER_ROLE) {
        paused = false;
        emit Unpaused();
    }

    function requestRefill() external {
        uint256 bal = axynomToken.balanceOf(rewardsPool);
        if (bal < rewardDebt) {
            emit RefillRequested(address(axynomToken), rewardDebt - bal);
        }
    }

    function getRewardDebt() external view returns (uint256) {
        return rewardDebt;
    }

    function getUserStakes(address user) external view returns (StakeInfo[] memory) {
        return userStakes[user];
    }

    function getAvailableReward(address user, uint256 index) external view returns (uint256) {
        StakeInfo memory s = userStakes[user][index];
        if (s.claimed) return 0;
        uint256 t = block.timestamp - s.startTimestamp;
        return StakeLogic.calculateReward(s.amount, s.apy, t);
    }

    function canContinueStake(address user, uint256 index) external view returns (bool) {
        if (index >= userStakes[user].length) return false;
        StakeInfo memory s = userStakes[user][index];
        return !s.claimed && block.timestamp >= s.startTimestamp + s.lockDuration;
    }

    function _authorizeUpgrade(address newImpl) internal override onlyRole(UPGRADER_ROLE) {}
}
