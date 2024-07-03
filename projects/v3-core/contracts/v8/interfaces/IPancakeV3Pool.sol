// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './pool/IPancakeV3PoolImmutables.sol';
import './pool/IPancakeV3PoolDerivedState.sol';
import './pool/IPancakeV3PoolActions.sol';
import './pool/IPancakeV3PoolOwnerActions.sol';
import './pool/IPancakeV3PoolEvents.sol';

/// @title The interface for a PancakeSwap V3 Pool
/// @notice A PancakeSwap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IPancakeV3Pool is
    IPancakeV3PoolImmutables,
    IPancakeV3PoolDerivedState,
    IPancakeV3PoolActions,
    IPancakeV3PoolOwnerActions,
    IPancakeV3PoolEvents
{
    error AlreadyInitialized();
    error InsufficientInputAmount();
    error InvalidPriceLimit();
    error Slot0Locked();
    error Unauthorized();
    error LowerTickMustBeBelowUpperTick();
    error LowerTickMustBeGreterOrEqualMinTick();
    error UpperTickMustBeLesserOrEqualMaxTick();
    error AmountSpecifiedCannotBeZero();
    error InsufficientLiquidity();
    error InsufficientBalanceOfToken0AfterFlash();
    error InsufficientBalanceOfToken1AfterFlash();
    error InvalidFeeProtocol();
    error InsufficientBalanceOfToken0();
    error InsufficientBalanceOfToken1();
    error NotInitializedLower();
    error NotInitializedUpper();
    error FlashLoanNotPaid();
    
    event SetLmPoolEvent(address addr);

    struct ModifyPositionParams {
        // the address that owns the position
        address owner;
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // any change in liquidity
        int128 liquidityDelta;
    }

    struct SwapCache {
        uint32 feeProtocol;
        uint128 liquidityStart;
        uint32 blockTimestamp;
        int56 tickCumulative;
        uint160 secondsPerLiquidityCumulativeX128;
        bool computedLatestObservation;
    }

    struct SwapState {
        uint256 amountSpecifiedRemaining;
        uint256 amountCalculated;
        uint160 sqrtPriceX96;
        int24 tick;
        uint256 feeGrowthGlobalX128;
        uint128 protocolFee;
        uint128 liquidity;
    }

    struct StepComputations {
        uint160 sqrtPriceStartX96;
        int24 tickNext;
        bool initialized;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
        uint256 feeAmount;
    }

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 observationIndex;
        uint16 observationCardinality;
        uint16 observationCardinalityNext;
        uint32 feeProtocol;
        bool unlocked;
    }

    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }    
}
