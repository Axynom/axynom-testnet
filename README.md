# Axynom Testnet Contracts

This repository contains the core smart contracts deployed on Arbitrum testnet for the Axynom protocol.

Axynom is a decentralized coordination protocol designed to reward meaningful contributions through a Proof-of-Growth (PoG) system, staking mechanics, and transparent reward flows. These contracts form the foundation of Axynom’s token logic, contributor infrastructure, and reward distribution mechanisms.

---

## Contracts Included

### Core Contracts

#### AxynomToken.sol  
Upgradeable ERC20 token that serves as the base currency of the Axynom ecosystem. All GP (Growth Point) redemptions and reward flows are settled in AXY.

#### AxynomStaking.sol  
Staking contract supporting fixed lock periods, tiered APYs, early withdrawal penalties, reward boosts, and proxy-safe upgradeability.

#### AxynomTreasury.sol  
Treasury contract designed to hold protocol-owned assets and provide funding for staking and PoG reward pools. Will be governed by a DAO in future phases.

#### ContributionRegistry.sol  
Registers all contributor submissions. Tracks contribution metadata, approval status, and GP awarded. Serves as the source of truth for on-chain contribution history.

#### PoG.sol  
Implements the Proof-of-Growth reward system. Distributes GP points based on validated contributions. Delegates reward math and logic to modular libraries.

#### RewardsPool.sol  
Handles reward liquidity and payout coordination for staking and PoG systems. Ensures sustainable distribution by comparing available reserves with protocol-wide debt.

---

### Supporting Libraries & Modules

#### PenaltyLogic.sol  
Calculates early withdrawal penalties based on the staker’s lock period and time elapsed. Routes penalized funds to the Treasury contract.

#### PoGLogic.sol  
Contains the reward logic for the PoG system, including dynamic GP assignments based on contribution metadata.

#### PoolInteractions.sol  
Abstracts internal contract calls to the staking and rewards pools, ensuring safe interactions and minimizing duplication.

#### RewardRouter.sol  
Manages multi-token reward routing between systems, including potential future integrations and extensions.

#### StakeLogic.sol  
Encapsulates stake tracking, lock period enforcement, APY logic, and compound staking behavior.

#### TreasuryInvestments.sol  
Handles on-chain treasury investment strategies and fund flow tracking. Supports protocol-owned yield optimization logic.

---

## Deployment Notes

These contracts are live on the Arbitrum testnet and are structured using upgradeable proxy patterns and modular logic libraries. Each contract is written with upgrade safety, role-based permissions, and audit-readiness in mind.

---

## Security and Architecture

- Upgradeable via transparent proxy pattern
- Role-based access control (`AccessControl`)
- Modular logic separation (`StakeLogic`, `PenaltyLogic`, `PoolInteractions`)
- Designed for DAO governance integration
- Built with a focus on transparency and long-term sustainability

---

## License

This repository is licensed under the MIT License. See the `LICENSE` file for details.

---

## Additional Resources

- Project Website: [https://axynom.com](https://axynom.com)
- Documentation: [https://docs.axynom.com](https://docs.axynom.com)
- Arbitrum Testnet Explorer: [https://testnet.arbiscan.io](https://testnet.arbiscan.io)

---

**Note:** These contracts are part of the Axynom public testnet release. All logic and systems are subject to further review, testing, and revision before mainnet deployment.
