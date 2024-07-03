// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import './v8/interfaces/IPancakeV3PoolDeployer.sol';

import './PancakeV3Pool.sol';

contract PancakeV3PoolDeployer is IPancakeV3PoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    error NotFactory();
    error AlreadyInitialized();

    /// @inheritdoc IPancakeV3PoolDeployer
    Parameters public override parameters;

    address public factoryAddress;

    function setFactoryAddress(address _factoryAddress) external {
        if (factoryAddress != address(0)) {
            revert AlreadyInitialized();
        }

        factoryAddress = _factoryAddress;
    }

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the PancakeSwap V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) external override returns (address pool) {
        if (msg.sender != factoryAddress) {
            revert NotFactory();
        }

        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new PancakeV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}
