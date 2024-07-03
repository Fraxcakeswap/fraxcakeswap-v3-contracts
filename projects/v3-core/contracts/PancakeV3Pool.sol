// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import './v8/interfaces/IPancakeV3Pool.sol';

import './v8/libraries/Tick.sol';
import './v8/libraries/TickBitmap.sol';
import './v8/libraries/Position.sol';
import './v8/libraries/Oracle.sol';

import './v8/libraries/PRBMath.sol';
import './v8/libraries/FixedPoint128.sol';
import './v8/libraries/TickMath.sol';
import './v8/libraries/LiquidityMath.sol';
import './v8/libraries/SqrtPriceMath.sol';
import './v8/libraries/SwapMath.sol';

import './v8/interfaces/IPancakeV3PoolDeployer.sol';
import './v8/interfaces/callback/IPancakeV3MintCallback.sol';
import './v8/interfaces/callback/IPancakeV3SwapCallback.sol';
import './v8/interfaces/callback/IPancakeV3FlashCallback.sol';

import './v8/interfaces/minimal/IERC20Minimal.sol';
import './v8/interfaces/minimal/IPancakeV3LmPool.sol';
import './v8/interfaces/minimal/IPancakeV3Factory.sol';

contract PancakeV3Pool is IPancakeV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Oracle for Oracle.Observation[65535];

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;

    int24 public immutable tickSpacing;

    uint128 public immutable maxLiquidityPerTick;

    uint32  internal constant PROTOCOL_FEE_SP = 65536;

    uint256 internal constant PROTOCOL_FEE_DENOMINATOR = 10000;

    Slot0 public slot0;

    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;

    ProtocolFees public protocolFees;
    uint128 public liquidity;

    mapping(int24 => Tick.Info) public ticks;
    mapping(int16 => uint256) public tickBitmap;
    mapping(bytes32 => Position.Info) public positions;
    Oracle.Observation[65535] public observations;

    IPancakeV3LmPool public lmPool;

    modifier lock() {
        if (!slot0.unlocked) revert Slot0Locked();
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    modifier onlyFactoryOrFactoryOwner() {
        if(msg.sender != factory && msg.sender != IPancakeV3Factory(factory).owner()) revert Unauthorized();
        _;
    }

    constructor() {
        int24 _tickSpacing;
        (factory, token0, token1, fee, _tickSpacing) = IPancakeV3PoolDeployer(msg.sender).parameters();
        tickSpacing = _tickSpacing;

        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    }

    function checkTicks(int24 tickLower, int24 tickUpper) private pure {
        if(tickLower >= tickUpper) revert LowerTickMustBeBelowUpperTick();
        if(tickLower < TickMath.MIN_TICK) revert LowerTickMustBeGreterOrEqualMinTick();
        if(tickUpper > TickMath.MAX_TICK) revert UpperTickMustBeLesserOrEqualMaxTick();
    }

    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        return
            observations.observe(
                _blockTimestamp(),
                secondsAgos,
                slot0.tick,
                slot0.observationIndex,
                liquidity,
                slot0.observationCardinality
            );
    }

    function increaseObservationCardinalityNext(uint16 observationCardinalityNext)
        external
        override
        lock
    {
        uint16 observationCardinalityNextOld = slot0.observationCardinalityNext; // for the event
        uint16 observationCardinalityNextNew = observations.grow(
            observationCardinalityNextOld,
            observationCardinalityNext
        );
        slot0.observationCardinalityNext = observationCardinalityNextNew;
        if (observationCardinalityNextOld != observationCardinalityNextNew)
            emit IncreaseObservationCardinalityNext(observationCardinalityNextOld, observationCardinalityNextNew);
    }

    function initialize(uint160 sqrtPriceX96) external override {
        if(slot0.sqrtPriceX96 != 0) revert AlreadyInitialized();

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(_blockTimestamp());

        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            observationIndex: 0,
            observationCardinality: cardinality,
            observationCardinalityNext: cardinalityNext,
            feeProtocol: 209718400, // default value for all pools, 3200:3200, store 2 uint32 inside
            unlocked: true
        });

        if (fee == 100) {
            slot0.feeProtocol = 216272100; // value for 3300:3300, store 2 uint32 inside
        } else if (fee == 500) {
            slot0.feeProtocol = 222825800; // value for 3400:3400, store 2 uint32 inside
        }

        emit Initialize(sqrtPriceX96, tick);
    }

    function _modifyPosition(ModifyPositionParams memory params)
        private
        returns (
            Position.Info storage position,
            int256 amount0,
            int256 amount1
        )
    {
        // gas optimizations
        Slot0 memory slot0_ = slot0;
        uint256 feeGrowthGlobal0X128_ = feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128_ = feeGrowthGlobal1X128;

        position = positions.get(
            params.owner,
            params.tickLower,
            params.tickUpper
        );

        uint32 time = _blockTimestamp();
        (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) = observations.observeSingle(
            time,
            0,
            slot0.tick,
            slot0.observationIndex,
            liquidity,
            slot0.observationCardinality
        );

        bool flippedLower = ticks.update(
            params.tickLower,
            slot0_.tick,
            int128(params.liquidityDelta),
            feeGrowthGlobal0X128_,
            feeGrowthGlobal1X128_,
            secondsPerLiquidityCumulativeX128,
            tickCumulative,
            time,
            false,
            maxLiquidityPerTick
        );
                
        bool flippedUpper = ticks.update(
            params.tickUpper,
            slot0_.tick,
            int128(params.liquidityDelta),
            feeGrowthGlobal0X128_,
            feeGrowthGlobal1X128_,
            secondsPerLiquidityCumulativeX128,
            tickCumulative,
            time,
            true,
            maxLiquidityPerTick
        );

        if (flippedLower) {
            tickBitmap.flipTick(params.tickLower, int24(tickSpacing));
        }

        if (flippedUpper) {
            tickBitmap.flipTick(params.tickUpper, int24(tickSpacing));
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks
            .getFeeGrowthInside(
                params.tickLower,
                params.tickUpper,
                slot0_.tick,
                feeGrowthGlobal0X128_,
                feeGrowthGlobal1X128_
            );

        position.update(
            params.liquidityDelta,
            feeGrowthInside0X128,
            feeGrowthInside1X128
        );

        if (slot0_.tick < params.tickLower) {
            amount0 = SqrtPriceMath.calcAmount0Delta(
                TickMath.getSqrtRatioAtTick(params.tickLower),
                TickMath.getSqrtRatioAtTick(params.tickUpper),
                params.liquidityDelta
            );
        } else if (slot0_.tick < params.tickUpper) {
            amount0 = SqrtPriceMath.calcAmount0Delta(
                slot0_.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(params.tickUpper),
                params.liquidityDelta
            );

            amount1 = SqrtPriceMath.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.tickLower),
                slot0_.sqrtPriceX96,
                params.liquidityDelta
            );

            liquidity = LiquidityMath.addLiquidity(
                liquidity,
                params.liquidityDelta
            );
        } else {
            amount1 = SqrtPriceMath.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.tickLower),
                TickMath.getSqrtRatioAtTick(params.tickUpper),
                params.liquidityDelta
            );
        }
    }

    /// @inheritdoc IPancakeV3PoolActions
    /// @dev noDelegateCall is applied indirectly via _modifyPosition
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        if(amount == 0) revert AmountSpecifiedCannotBeZero();
        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int128(amount)
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = IERC20Minimal(token0).balanceOf(address(this));
        if (amount1 > 0) balance1Before = IERC20Minimal(token1).balanceOf(address(this));
        IPancakeV3MintCallback(msg.sender).pancakeV3MintCallback(amount0, amount1, data);
        if (
            (amount0 > 0 && balance0Before + amount0 > IERC20Minimal(token0).balanceOf(address(this)))
            || (amount1 > 0 && balance1Before + amount1 > IERC20Minimal(token1).balanceOf(address(this)))
        ) revert InsufficientInputAmount();

        emit Mint(msg.sender, recipient, tickLower, tickUpper, amount, amount0, amount1);
    }

    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock returns (uint128 amount0, uint128 amount1) {
        Position.Info storage position = positions.get(msg.sender, tickLower, tickUpper);

        amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            IERC20Minimal(token0).transfer(recipient, amount0);
        }
        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            IERC20Minimal(token1).transfer(recipient, amount1);
        }

        emit Collect(msg.sender, recipient, tickLower, tickUpper, amount0, amount1);
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        if(amountSpecified == 0) revert AmountSpecifiedCannotBeZero();
        Slot0 memory slot0Start = slot0;

        if(!slot0Start.unlocked) revert Slot0Locked();
        if (
            zeroForOne
                ? sqrtPriceLimitX96 >= slot0Start.sqrtPriceX96 ||
                    sqrtPriceLimitX96 <= TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 <= slot0Start.sqrtPriceX96 ||
                    sqrtPriceLimitX96 >= TickMath.MAX_SQRT_RATIO
        ) revert InvalidPriceLimit();

        slot0.unlocked = false;

        SwapCache memory cache = SwapCache({
            liquidityStart: liquidity,
            blockTimestamp: _blockTimestamp(),
            feeProtocol: zeroForOne ? (slot0Start.feeProtocol % PROTOCOL_FEE_SP) : (slot0Start.feeProtocol >> 16),
            secondsPerLiquidityCumulativeX128: 0,
            tickCumulative: 0,
            computedLatestObservation: false
        });

        if (address(lmPool) != address(0)) {
          lmPool.accumulateReward(cache.blockTimestamp);
        }

        bool exactInput = amountSpecified > 0;

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: uint256(amountSpecified),
            amountCalculated: 0,
            sqrtPriceX96: slot0Start.sqrtPriceX96,
            tick: slot0Start.tick,
            feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
            protocolFee: 0,
            liquidity: cache.liquidityStart
        });

        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                int24(tickSpacing),
                zeroForOne
            );

            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                IPancakeV3Factory(factory).getSwapFee(msg.sender, fee)
            );

            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount);
                state.amountCalculated = state.amountCalculated - step.amountOut;
            } else {
                state.amountSpecifiedRemaining += step.amountOut;
                state.amountCalculated = state.amountCalculated + (step.amountIn + step.feeAmount);
            }

            if (cache.feeProtocol > 0) {
                uint256 delta = (step.feeAmount * cache.feeProtocol) / PROTOCOL_FEE_DENOMINATOR;
                step.feeAmount -= delta;
                state.protocolFee += uint128(delta);
            }

            if (state.liquidity > 0)
                state.feeGrowthGlobalX128 += PRBMath.mulDiv(
                    step.feeAmount,
                    FixedPoint128.Q128, 
                    state.liquidity
                );

            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    if (!cache.computedLatestObservation) {
                        (cache.tickCumulative, cache.secondsPerLiquidityCumulativeX128) = observations.observeSingle(
                            cache.blockTimestamp,
                            0,
                            slot0Start.tick,
                            slot0Start.observationIndex,
                            cache.liquidityStart,
                            slot0Start.observationCardinality
                        );
                        cache.computedLatestObservation = true;
                    }

                    if (address(lmPool) != address(0)) {
                      lmPool.crossLmTick(step.tickNext, zeroForOne);
                    }

                    int128 liquidityNet = ticks.cross(
                        step.tickNext,
                        (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
                        (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128),
                        cache.secondsPerLiquidityCumulativeX128,
                        cache.tickCumulative,
                        cache.blockTimestamp
                    );
                    if (zeroForOne) liquidityNet = -liquidityNet;

                    state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityNet);
                }

                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        if (state.tick != slot0Start.tick) {
            (uint16 observationIndex, uint16 observationCardinality) = observations.write(
                slot0Start.observationIndex,
                cache.blockTimestamp,
                slot0Start.tick,
                cache.liquidityStart,
                slot0Start.observationCardinality,
                slot0Start.observationCardinalityNext
            );
            (slot0.sqrtPriceX96, slot0.tick, slot0.observationIndex, slot0.observationCardinality) = (
                state.sqrtPriceX96,
                state.tick,
                observationIndex,
                observationCardinality
            );
        } else {
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        if (cache.liquidityStart != state.liquidity) liquidity = state.liquidity;

        uint128 protocolFeesToken0 = 0;
        uint128 protocolFeesToken1 = 0;

        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token0 += state.protocolFee;
            protocolFeesToken0 = state.protocolFee;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token1 += state.protocolFee;
            protocolFeesToken1 = state.protocolFee;
        }

        (amount0, amount1) = zeroForOne == exactInput
            ? (amountSpecified - int256(state.amountSpecifiedRemaining), int256(state.amountCalculated))
            : (int256(state.amountCalculated), amountSpecified - int256(state.amountSpecifiedRemaining));

        if (zeroForOne) {
            if (amount1 < 0) IERC20Minimal(token1).transfer(recipient, type(uint256).max - uint256(amount1));

            uint256 balance0Before = IERC20Minimal(token0).balanceOf(address(this));
            IPancakeV3SwapCallback(msg.sender).pancakeV3SwapCallback(amount0, amount1, data);
            if (balance0Before + uint256(amount0) > IERC20Minimal(token0).balanceOf(address(this)))
                revert InsufficientInputAmount();
        } else {
            if (amount0 < 0) IERC20Minimal(token0).transfer(recipient, type(uint256).max - uint256(amount0));

            uint256 balance1Before = IERC20Minimal(token1).balanceOf(address(this));
            IPancakeV3SwapCallback(msg.sender).pancakeV3SwapCallback(amount0, amount1, data);
            if (balance1Before + uint256(amount1) > IERC20Minimal(token1).balanceOf(address(this)))
                revert InsufficientInputAmount();
        }

        emit Swap(
            msg.sender,
            recipient,
            amount0,
            amount1,
            state.sqrtPriceX96,
            state.liquidity,
            state.tick,
            protocolFeesToken0,
            protocolFeesToken1
        );
        slot0.unlocked = true;
    }

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override lock {
        uint128 _liquidity = liquidity;
        if (_liquidity == 0) revert InsufficientLiquidity();

        uint256 fee0 = SqrtPriceMath.mulDivRoundingUp(amount0, fee, 1e6);
        uint256 fee1 = SqrtPriceMath.mulDivRoundingUp(amount1, fee, 1e6);
        uint256 balance0Before = IERC20Minimal(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20Minimal(token1).balanceOf(address(this));

        if (amount0 > 0) IERC20Minimal(token0).transfer(recipient, amount0);
        if (amount1 > 0) IERC20Minimal(token1).transfer(recipient, amount1);

        IPancakeV3FlashCallback(msg.sender).pancakeV3FlashCallback(
            fee0,
            fee1,
            data
        );

        if (IERC20Minimal(token0).balanceOf(address(this)) < balance0Before + fee0)
            revert FlashLoanNotPaid();
        if (IERC20Minimal(token1).balanceOf(address(this)) < balance1Before + fee1)
            revert FlashLoanNotPaid();

        emit Flash(msg.sender, recipient, amount0, amount1);
    }

    function setFeeProtocol(uint32 feeProtocol0, uint32 feeProtocol1) external override lock onlyFactoryOrFactoryOwner {
        if(
            (feeProtocol0 > 0 && (feeProtocol0 < 1000 || feeProtocol0 > 4000))
            || (feeProtocol1 > 0 && (feeProtocol1 < 1000 || feeProtocol1 > 4000))
        ) revert InvalidFeeProtocol();

        uint32 feeProtocolOld = slot0.feeProtocol;
        slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 16);
        emit SetFeeProtocol(
            feeProtocolOld % PROTOCOL_FEE_SP,
            feeProtocolOld >> 16,
            feeProtocol0,
            feeProtocol1
        );
    }

    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock onlyFactoryOrFactoryOwner returns (uint128 amount0, uint128 amount1) {
        amount0 = amount0Requested > protocolFees.token0 ? protocolFees.token0 : amount0Requested;
        amount1 = amount1Requested > protocolFees.token1 ? protocolFees.token1 : amount1Requested;

        if (amount0 > 0) {
            if (amount0 == protocolFees.token0) amount0--; // ensure that the slot is not cleared, for gas savings
            protocolFees.token0 -= amount0;
            IERC20Minimal(token0).transfer(recipient, amount0);
        }
        if (amount1 > 0) {
            if (amount1 == protocolFees.token1) amount1--; // ensure that the slot is not cleared, for gas savings
            protocolFees.token1 -= amount1;
            IERC20Minimal(token1).transfer(recipient, amount1);
        }

        emit CollectProtocol(msg.sender, recipient, amount0, amount1);
    }

    function setLmPool(address _lmPool) external override onlyFactoryOrFactoryOwner {
      lmPool = IPancakeV3LmPool(_lmPool);
      emit SetLmPoolEvent(address(_lmPool));
    }
}
