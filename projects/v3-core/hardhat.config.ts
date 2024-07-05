import type { HardhatUserConfig, NetworkUserConfig } from 'hardhat/types'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import 'hardhat-watcher'
import 'dotenv/config'
import 'solidity-docgen'
require('dotenv').config({ path: require('find-config')('.env') })

const LOW_OPTIMIZER_COMPILER_SETTINGS = {
  version: '0.7.6',
  settings: {
    optimizer: {
      enabled: true,
      runs: 2_000,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const LOWEST_OPTIMIZER_COMPILER_SETTINGS = {
  version: '0.7.6',
  settings: {
    optimizer: {
      enabled: true,
      runs: 400,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const LOWEST_8_OPTIMIZER_COMPILER_SETTINGS = {
  version: '0.8.19',
  settings: {
    optimizer: {
      enabled: true,
      runs: 400,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const DEFAULT_COMPILER_SETTINGS = {
  version: '0.7.6',
  settings: {
    evmVersion: 'istanbul',
    optimizer: {
      enabled: true,
      runs: 1_000_000,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const DEFAULT_8_COMPILER_SETTINGS = {
  version: '0.8.19',
  settings: {
    optimizer: {
      enabled: true,
      runs: 1_000_000,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const fraxTestnet: NetworkUserConfig = {
  url: 'https://rpc.testnet.frax.com',
  chainId: 2522,
  accounts: [process.env.KEY_FRAX_TESTNET!],
};

const bscTestnet: NetworkUserConfig = {
  url: 'https://data-seed-prebsc-1-s1.binance.org:8545/',
  chainId: 97,
  accounts: [process.env.KEY_TESTNET!],
}

const bscMainnet: NetworkUserConfig = {
  url: 'https://bsc-dataseed.binance.org/',
  chainId: 56,
  accounts: [process.env.KEY_MAINNET!],
}

const goerli: NetworkUserConfig = {
  url: 'https://rpc.ankr.com/eth_goerli',
  chainId: 5,
  accounts: [process.env.KEY_GOERLI!],
}

const eth: NetworkUserConfig = {
  url: 'https://eth.llamarpc.com',
  chainId: 1,
  accounts: [process.env.KEY_ETH!],
}

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    ...(process.env.KEY_FRAX_TESTNET && { fraxTestnet }),
    ...(process.env.KEY_TESTNET && { bscTestnet }),
    ...(process.env.KEY_MAINNET && { bscMainnet }),
    ...(process.env.KEY_GOERLI && { goerli }),
    ...(process.env.KEY_ETH && { eth }),
    // mainnet: bscMainnet,
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || '',
      fraxTestnet: process.env.ETHERSCAN_API_KEY || '',
    },
    customChains: [
      {
        network: 'fraxTestnet',
        chainId: 2522,
        urls: {
          apiURL: "https://api-holesky.fraxscan.com/api",
          browserURL: "https://holesky.fraxscan.com",
        },
      },
    ],
  },
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS],
    overrides: {
      'contracts/PancakeV3Pool.sol': LOWEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/PancakeV3PoolDeployer.sol': LOWEST_OPTIMIZER_COMPILER_SETTINGS,
      // 'contracts/test/OutputCodeHash.sol': LOWEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/Pancakev3Factory.sol': DEFAULT_COMPILER_SETTINGS,
      'contracts/SwapFee.sol': DEFAULT_8_COMPILER_SETTINGS,
      // 'contracts/v8/libraries/LiquidityMath.sol': DEFAULT_8_COMPILER_SETTINGS,
      // 'contracts/v8/libraries/Oracle.sol': DEFAULT_8_COMPILER_SETTINGS,
      // 'contracts/v8/libraries/Position.sol': DEFAULT_8_COMPILER_SETTINGS,
      // 'contracts/v8/libraries/PRBMath.sol': DEFAULT_8_COMPILER_SETTINGS,
      // 'contracts/v8/libraries/SqrtPriceMath.sol': DEFAULT_8_COMPILER_SETTINGS,
      // 'contracts/v8/libraries/SwapMath.sol': DEFAULT_8_COMPILER_SETTINGS,
      // 'contracts/v8/libraries/Tick.sol': DEFAULT_8_COMPILER_SETTINGS,
      // 'contracts/v8/libraries/TickBitmap.sol': DEFAULT_8_COMPILER_SETTINGS,
      // 'contracts/v8/libraries/TickMath.sol': DEFAULT_8_COMPILER_SETTINGS,
    },
  },
  watcher: {
    test: {
      tasks: [{ command: 'test', params: { testFiles: ['{path}'] } }],
      files: ['./test/**/*'],
      verbose: true,
    },
  },
  docgen: {
    pages: 'files',
  },
}
