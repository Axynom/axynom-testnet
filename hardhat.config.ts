import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';
import * as dotenv from "dotenv";

dotenv.config();

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
const RPC_URL = process.env.RPC_URL || "";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    arbitrumSepolia: {
      url: RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 421614
    },
    arbitrum: {
      url: RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 42161
    }
  }
};

export default config;
