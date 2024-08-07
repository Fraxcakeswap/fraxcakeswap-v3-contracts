import { verifyContract } from '@pancakeswap/common/verify'
import { sleep } from '@pancakeswap/common/sleep'

async function main() {
  const networkName = network.name
  const deployedContracts = await import(`@pancakeswap/v3-core/deployments/${networkName}.json`)

  // Verify PancakeV3Pool
  console.log('Verify PancakeV3Pool')
  await verifyContract("0x1eFd7067E0081a92D223E2B0D0392eBB54482286")//deployedContracts.PancakeV3Pool)
  await sleep(10000)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
