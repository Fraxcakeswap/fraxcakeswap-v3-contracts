// import { verifyContract } from '@pancakeswap/common/verify'
import { sleep } from '@pancakeswap/common/sleep'
import { run } from 'hardhat'

async function main() {
  const networkName = network.name
  const deployedContracts = await import(`@pancakeswap/v3-core/deployments/${networkName}.json`)

  // Verify PancakeV3PoolDeployer
  console.log('Verify PancakeV3PoolDeployer')
  await verifyContract('contracts/PancakeV3PoolDeployer:PancakeV3PoolDeployer', deployedContracts.PancakeV3PoolDeployer)
  await sleep(10000)

  // Verify pancakeV3Factory
  console.log('Verify pancakeV3Factory')
  await verifyContract('contracts/PancakeV3Factory:PancakeV3Factory', deployedContracts.PancakeV3Factory, [deployedContracts.PancakeV3PoolDeployer])
  await sleep(10000)
}

async function verifyContract(path: string, contract: string, constructorArguments: any[] = []) {
  if (process.env.ETHERSCAN_API_KEY && process.env.NETWORK !== 'hardhat') {
    try {
      console.info('Verifying', contract, constructorArguments)
      const verify = await run('verify:verify', {
        address: contract,
        contract: path,
        constructorArguments,
      })
      console.log(contract, ' verify successfully')
    } catch (error) {
      console.log(
        '....................',
        contract,
        ' error start............................',
        '\n',
        error,
        '\n',
        '....................',
        contract,
        ' error end............................'
      )
    }
  }
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
