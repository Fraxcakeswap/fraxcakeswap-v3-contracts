import { verifyContract } from '@pancakeswap/common/verify'
import { sleep } from '@pancakeswap/common/sleep'

async function main() {
  const networkName = network.name
  const deployedContracts = await import(`@pancakeswap/v3-core/deployments/${networkName}.json`)

  // Verify SwapFee
  console.log('Verify SwapFee')
  await verifyContract("0xa88B7b20fE4b88A0C7C56521366414441ef4cF05", ["0xdfda88b50cb13b4bcd3abb224310344772036b96", 2, 8, 32, 2000, 1000, 500])//deployedContracts.PancakeV3Pool)
  await sleep(10000)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
