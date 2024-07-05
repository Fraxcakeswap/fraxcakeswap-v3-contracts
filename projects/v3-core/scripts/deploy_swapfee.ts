/* eslint-disable camelcase */
import { ethers, run, network } from "hardhat";
import { configs } from "@pancakeswap/common/config";
import { tryVerify } from "@pancakeswap/common/verify";
import { writeFileSync } from "fs";

async function main() {
  // Get network data from Hardhat config (see hardhat.config.ts).
  const networkName = network.name;
  // Check if the network is supported.
  console.log(`Deploying to ${networkName} network...`);

  // Compile contracts.
  await run("compile");
  console.log("Compiled contracts...");

  const config = configs[networkName as keyof typeof configs];
  if (!config) {
    throw new Error(`No config found for network ${networkName}`);
  }

  const v3CoreDeployedContracts = await import(`@pancakeswap/v3-core/deployments/${networkName}.json`);
  const pancakeV3Factory_address = v3CoreDeployedContracts.PancakeV3Factory;

  const SwapFee = await ethers.getContractFactory("SwapFee");
  const swapFee = await SwapFee.deploy("0xdfda88b50cb13b4bcd3abb224310344772036b96", 2, 8, 32, 2000, 1000, 500);

  console.log("Swap Fee deployed to:", swapFee.address);
  // await tryVerify(swapFee, ["0xdfda88b50cb13b4bcd3abb224310344772036b96"]);

  const PancakeV3Factory = await ethers.getContractFactory("PancakeV3Factory");
  const pancakeV3Factory = PancakeV3Factory.attach(pancakeV3Factory_address);
  await pancakeV3Factory.setSwapFee(swapFee.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
