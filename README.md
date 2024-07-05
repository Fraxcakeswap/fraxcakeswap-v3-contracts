# Fraxcake V3

## Deployments

1. Add Key in `.env` file. It's a private key of the account that will deploy the contracts and should be gitignored.
2. fraxTestnet `KEY_FRAX_TESTNET`
3. add `ETHERSCAN_API_KEY` in `.env` file. It's an API key for fraxscan.
4. `yarn` in root directory
5. `NETWORK=$NETWORK yarn zx v3-deploy.mjs` where `$NETWORK` is either `fraxTestnet`, `eth`, `bscMainnet`, `bscTestnet` or `hardhat` (for local testing)
6. `NETWORK=$NETWORK yarn zx v3-verify.mjs` where `$NETWORK` is either `fraxTestnet`, `eth`, `bscMainnet`, `bscTestnet` or `hardhat` (for local testing)

Frax Testnet (Holesky):

SwapFee: [0xa88B7b20fE4b88A0C7C56521366414441ef4cF05](https://holesky.fraxscan.com/address/0xa88B7b20fE4b88A0C7C56521366414441ef4cF05)

fraxTestnet.json:
```json
{
  "MasterChefV3": "0x0A70A6daF694710EDf86b7ddCfD12899CF8d6E8d",
  "SmartRouter": "0x2ee8c9b1c3bcBA5fA5c0b26C0dBd45804Db4E5aB",
  "SmartRouterHelper": "0x204dd3CF7BA29Cc3b60396a8069e86f7D333cebe",
  "MixedRouteQuoterV1": "0xCD00988EC73D02b79768ca179651d4d4a544c17E",
  "QuoterV2": "0x03A5c237C3bF96eC2Dc19e8336De0659e7D5b60a",
  "TokenValidator": "0xD2c207C198B21E78579030CB4533EFc186540Afb",
  "PancakeV3Factory": "0xDC28090A6A694E678B821A63423a30F304fFE8bf",
  "PancakeV3PoolDeployer": "0xc2bacB41eA05A4484CE744e649d515ffA1736F08",
  "SwapRouter": "0x53822510127f7870d1ab15766F5754f3BE391d8f",
  "V3Migrator": "0xC3523f1248Eae66845C76dF9873fB3F3D396A11f",
  "TickLens": "0x1310B2bFC1a816C3d25F4feEf163f540F6CF1f45",
  "NonfungibleTokenPositionDescriptor": "0x9a00E190e4B7EbfDC1DaE66Ae847B2B3807504B1",
  "NonfungiblePositionManager": "0x9126c64a593EB84db0e9af7c5cCecE84cD7FEc48",
  "PancakeInterfaceMulticall": "0x92062832BB94172a0938000B2695936a4845c883",
  "PancakeV3LmPoolDeployer": "0x319274BC56956624B42208E7fCCF1F961D2a46bE"
}
```

## Changes to FraxcakeSwap V3 to Integrate Swap Fee Logic

### PancakeV3Pool.sol

The `PancakeV3Pool.sol` contract has been updated to incorporate a dynamic swap fee mechanism. This is achieved by fetching the swap fee from a `SwapFee` contract instead of using a static fee value. Here are the specific changes made:

1. **Modified SwapMath.computeSwapStep Call**:
    The original code:
    ```solidity
    (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
        state.sqrtPriceX96,
        (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
            ? sqrtPriceLimitX96
            : step.sqrtPriceNextX96,
        state.liquidity,
        state.amountSpecifiedRemaining,
        fee
    );
    ```
    has been updated to:
    ```solidity
    (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
        state.sqrtPriceX96,
        (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
            ? sqrtPriceLimitX96
            : step.sqrtPriceNextX96,
        state.liquidity,
        state.amountSpecifiedRemaining,
        IPancakeV3Factory(factory).getSwapFee(msg.sender, fee)
    );
    ```
    This change fetches the swap fee dynamically using the `getSwapFee` function from the factory contract.

### PancakeV3Factory.sol

The `PancakeV3Factory.sol` contract has been updated to include a mechanism for setting and getting the swap fee based on the client's address and predefined tiers. Here are the specific changes made:

1. **Swap Fee Storage and Setter Function**:
    ```solidity
    address public swapFee;

    function setSwapFee(address _swapFee) external onlyOwner {
        swapFee = _swapFee;
    }
    ```

2. **Dynamic Swap Fee Getter Function**:
    ```solidity
    function getSwapFee(address _client, uint24 _fee) external view override returns (uint24) {
        if (swapFee == address(0)) {
            return _fee;
        }

        return ISwapFee(swapFee).swapFee(_client, _fee);
    }
    ```
    This function checks if a `swapFee` contract is set. If not, it returns the default fee. Otherwise, it fetches the fee from the `SwapFee` contract based on the client's address and the default fee.

## Temporary Deletion of Events

Some events in the `PancakeV3Factory.sol` contract have been temporarily deleted during the development phase. These events will be restored or redesigned in the final version of the code to ensure proper logging and monitoring of key actions within the contract.

