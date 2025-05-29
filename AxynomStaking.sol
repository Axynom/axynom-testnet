// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./libraries/StakeLogic.sol";
import "./libraries/StakingUtils.sol";
import "./libraries/PoolInteractions.sol";

contract AxynomStaking is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using StakeLogic for StakeLogic.StakeInfo;
    using StakingUtils for uint256;

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

    struct LockConfig {
        uint256 duration;
        uint256 apy;
    }

    mapping(address => StakeInfo[]) public userStakes;
    mapping(LockPeriod => uint256) public capPerTier;
    mapping(LockPeriod => uint256) public totalStakedPerTier;
    mapping(LockPeriod => LockConfig) public lockConfig;

    uint256 public totalStaked;
    uint256 public rewardDebt;
    bool public paused;

    modifier notPaused() {
        require(!paused, "Staking is paused");
        _;
    }

    event Staked(address indexed user, uint256 amount, LockPeriod period, uint256 apy, uint256 index, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 reward, uint256 penalty, uint256 index);
    event ContinuedStake(address indexed user, uint256 index, uint256 newAmount, uint256 bonusApy);
    event RewardsPoolUpdated(address pool);
    event TreasuryUpdated(address treasury);
    event StakingCapUpdated(LockPeriod indexed period, uint256 newCap);
    event LockParamsUpdated(LockPeriod indexed period, uint256 newDuration, uint256 newApy);
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

        lockConfig[LockPeriod.SIX_MONTHS] = LockConfig(180 days, 5);
        lockConfig[LockPeriod.ONE_YEAR] = LockConfig(365 days, 12);
        lockConfig[LockPeriod.TWO_YEARS] = LockConfig(730 days, 30);
    }

    function stake(uint256 _amount, LockPeriod _period) external notPaused nonReentrant {
        require(_amount > 0, "Cannot stake 0");
        LockConfig memory config = lockConfig[_period];

        require(totalStakedPerTier[_period] + _amount <= capPerTier[_period], "Staking cap exceeded");

        totalStaked += _amount;
        totalStakedPerTier[_period] += _amount;

        axynomToken.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 estimatedReward = StakeLogic.calculateReward(_amount, config.apy, config.duration);
        rewardDebt += estimatedReward;

        userStakes[msg.sender].push(StakeInfo({
            amount: _amount,
            startTimestamp: block.timestamp,
            lockDuration: config.duration,
            apy: config.apy,
            claimed: false
        }));

        emit Staked(msg.sender, _amount, _period, config.apy, userStakes[msg.sender].length - 1, block.timestamp);
    }

    function unstake(uint256 index) external notPaused nonReentrant {
        require(treasury != address(0), "Treasury not set");
        require(index < userStakes[msg.sender].length, "Invalid index");

        StakeInfo storage stakeData = userStakes[msg.sender][index];
        require(!stakeData.claimed, "Already claimed");

        uint256 elapsed = block.timestamp - stakeData.startTimestamp;
        uint256 reward;
        uint256 penalty;

        if (elapsed < (stakeData.lockDuration * 66) / 100) {
            reward = StakeLogic.calculateReward(stakeData.amount, stakeData.apy, elapsed);
            penalty = reward;
            reward = 0;

            rewardDebt -= penalty;
            PoolInteractions.sendReward(address(axynomToken), treasury, penalty);
        } else if (elapsed < stakeData.lockDuration) {
            reward = StakeLogic.calculateReward(stakeData.amount, stakeData.apy, elapsed);
            penalty = (reward * 34) / 100;
            reward -= penalty;

            rewardDebt -= (reward + penalty);
            PoolInteractions.sendReward(address(axynomToken), treasury, penalty);
        } else {
            reward = StakeLogic.calculateReward(stakeData.amount, stakeData.apy, stakeData.lockDuration);
            rewardDebt -= reward;
        }

        totalStaked -= stakeData.amount;
        totalStakedPerTier[LockPeriod(stakeData.lockDuration.getPeriodFromDuration())] -= stakeData.amount;
        stakeData.claimed = true;

        PoolInteractions.sendReward(address(axynomToken), msg.sender, stakeData.amount + reward);
        emit Unstaked(msg.sender, stakeData.amount, reward, penalty, index);
    }

    function continueStake(uint256 index) external notPaused nonReentrant {
        require(index < userStakes[msg.sender].length, "Invalid index");
        StakeInfo storage s = userStakes[msg.sender][index];
        require(!s.claimed, "Already claimed");
        require(block.timestamp >= s.startTimestamp + s.lockDuration, "Stake not matured");

        uint256 reward = StakeLogic.calculateReward(s.amount, s.apy, s.lockDuration);
        uint256 newAmount = s.amount + reward;
        uint256 bonusApy = (s.apy * 110) / 100;
        uint256 newReward = StakeLogic.calculateReward(newAmount, bonusApy, s.lockDuration);

        rewardDebt = rewardDebt - reward + newReward;
        totalStaked += reward;

        s.claimed = true;

        userStakes[msg.sender].push(StakeInfo({
            amount: newAmount,
            startTimestamp: block.timestamp,
            lockDuration: s.lockDuration,
            apy: bonusApy,
            claimed: false
        }));

        emit ContinuedStake(msg.sender, index, newAmount, bonusApy);
    }

    // ---------------- View ----------------

    function getUserStakes(address user) external view returns (StakeInfo[] memory) {
        return userStakes[user];
    }

    // ---------------- Admin ----------------

    function setCap(LockPeriod _period, uint256 _cap) external onlyRole(MANAGER_ROLE) {
        capPerTier[_period] = _cap;
        emit StakingCapUpdated(_period, _cap);
    }

    function setLockParams(LockPeriod _period, uint256 _duration, uint256 _apy) external onlyRole(MANAGER_ROLE) {
        lockConfig[_period] = LockConfig(_duration, _apy);
        emit LockParamsUpdated(_period, _duration, _apy);
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

    function _authorizeUpgrade(address newImpl) internal override onlyRole(UPGRADER_ROLE) {}
}
