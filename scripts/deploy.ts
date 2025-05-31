import { ethers, upgrades } from "hardhat";
/**
 * Deployment script for Axynom Protocol contracts using UUPS proxy pattern
 * 
 * Deployment order:
 * 1. AxynomToken (AXYN)
 * 2. AxynomTreasury
 * 3. RewardsPool
 * 4. ContributionRegistry
 * 5. AxynomStaking
 * 6. PoG (Proof of Governance)
 * 
 * Note: Make sure to set up your environment variables:
 * - PRIVATE_KEY: Your deployer wallet private key
 * - RPC_URL: The RPC URL of the network you're deploying to
 * - ETHERSCAN_API_KEY: For contract verification
 */

async function main() {
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // 1. Deploy AxynomToken
  console.log("\nDeploying AxynomToken...");
  const AxynomToken = await ethers.getContractFactory("AxynomToken");
  const axynomToken = await upgrades.deployProxy(AxynomToken, [
    deployer.address,  // admin
    ethers.ZeroAddress, // rewards (will be set later)
    ethers.ZeroAddress, // treasury (will be set later)
    ethers.ZeroAddress  // liquidity (will be set later)
  ], {
    initializer: 'initialize',
    kind: 'uups'
  });
  await axynomToken.waitForDeployment();
  console.log("AxynomToken deployed to:", await axynomToken.getAddress());

  // 2. Deploy AxynomTreasury
  console.log("\nDeploying AxynomTreasury...");
  const AxynomTreasury = await ethers.getContractFactory("AxynomTreasury");
  const axynomTreasury = await upgrades.deployProxy(AxynomTreasury, [deployer.address], {
    initializer: 'initialize',
    kind: 'uups'
  });
  await axynomTreasury.waitForDeployment();
  console.log("AxynomTreasury deployed to:", await axynomTreasury.getAddress());

  // 3. Deploy RewardsPool
  console.log("\nDeploying RewardsPool...");
  const RewardsPool = await ethers.getContractFactory("RewardsPool");
  const rewardsPool = await upgrades.deployProxy(RewardsPool, [deployer.address], {
    initializer: 'initialize',
    kind: 'uups'
  });
  await rewardsPool.waitForDeployment();
  console.log("RewardsPool deployed to:", await rewardsPool.getAddress());

  // 4. Deploy ContributionRegistry
  console.log("\nDeploying ContributionRegistry...");
  const ContributionRegistry = await ethers.getContractFactory("ContributionRegistry");
  const contributionRegistry = await upgrades.deployProxy(ContributionRegistry, [deployer.address], {
    initializer: 'initialize',
    kind: 'uups'
  });
  await contributionRegistry.waitForDeployment();
  console.log("ContributionRegistry deployed to:", await contributionRegistry.getAddress());

  // 5. Deploy AxynomStaking
  console.log("\nDeploying AxynomStaking...");
  const AxynomStaking = await ethers.getContractFactory("AxynomStaking");
  const axynomStaking = await upgrades.deployProxy(AxynomStaking, [
    await axynomToken.getAddress(),
    await rewardsPool.getAddress()
  ], {
    initializer: 'initialize',
    kind: 'uups'
  });
  await axynomStaking.waitForDeployment();
  console.log("AxynomStaking deployed to:", await axynomStaking.getAddress());

  // 6. Deploy PoG (now all addresses are available)
  console.log("\nDeploying PoG...");
  const PoG = await ethers.getContractFactory("PoG");
  const pog = await upgrades.deployProxy(PoG, [
    await contributionRegistry.getAddress(),
    await rewardsPool.getAddress(),
    await axynomToken.getAddress(),
    1n * 10n ** 18n // multiplier (1:1 ratio)
  ], {
    initializer: 'initialize',
    kind: 'uups'
  });
  await pog.waitForDeployment();
  console.log("PoG deployed to:", await pog.getAddress());

  // Set up contract permissions
  console.log("\nSetting up contract permissions...");
  
  // Update AxynomToken tax destinations
  console.log("\nUpdate AxynomToken tax destinations")
  await axynomToken.setTaxDestinations(
    await rewardsPool.getAddress(),
    await axynomTreasury.getAddress(),
    await axynomTreasury.getAddress() // Using treasury as LP for now
  );
  console.log("✅✅")
  
  // Set up treasury permissions
  console.log("\nSet up treasury permissions")
  await axynomTreasury.setRewardsPool(await rewardsPool.getAddress());
  console.log("✅✅")
  
  // Set up staking permissions
  console.log("\nSet up staking permissions")
  await axynomStaking.setTreasury(await axynomTreasury.getAddress());
  console.log("✅✅")
  
  // Set up rewards pool permissions
  console.log("\nSet up rewards pool permissions")
  await rewardsPool.authorize(await axynomStaking.getAddress(), true);
  await rewardsPool.authorize(await pog.getAddress(), true);
  await rewardsPool.approveConsumer(await axynomToken.getAddress(), await axynomStaking.getAddress());
  console.log("✅✅")

  console.log("\nDeployment and initialization completed successfully! ✅✅✅");

  // Log all deployed contract addresses
  console.log("\nDeployed Contract Addresses:");
  console.log("AxynomToken:", await axynomToken.getAddress());
  console.log("PoG:", await pog.getAddress());
  console.log("AxynomTreasury:", await axynomTreasury.getAddress());
  console.log("AxynomStaking:", await axynomStaking.getAddress());
  console.log("RewardsPool:", await rewardsPool.getAddress());
  console.log("ContributionRegistry:", await contributionRegistry.getAddress());
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
