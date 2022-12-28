// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {BunniHub, BunniKey} from "bunni/src/BunniHub.sol";
import {IBunniHub} from "bunni/src/interfaces/IBunniHub.sol";
import {UniswapDeployer} from "bunni/src/tests/lib/UniswapDeployer.sol";
import {SwapRouter} from "bunni/lib/v3-periphery/contracts/SwapRouter.sol";
import {ISwapRouter} from "bunni/lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Pool} from "bunni/lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "bunni/lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "forge-std/Test.sol";

import {WETH} from "solmate/tokens/WETH.sol";

import {TickMath} from "v3-core/libraries/TickMath.sol";

import {TestERC20} from "./mocks/TestERC20.sol";
import {UniswapPoorOracle} from "../src/UniswapPoorOracle.sol";

contract UniswapPoorOracleTest is Test, UniswapDeployer {
    uint24 constant FEE = 500;
    uint256 constant IN_RANGE_THRESHOLD = 5e17;
    uint256 constant RECORDING_MIN_LENGTH = 1 hours;
    uint256 constant RECORDING_MAX_LENGTH = 1 hours + 30 minutes;
    int24 constant TICK_LOWER = -10;
    int24 constant TICK_UPPER = 10;

    WETH weth;
    BunniKey key;
    TestERC20 tokenA;
    TestERC20 tokenB;
    BunniHub bunniHub;
    SwapRouter router;
    IUniswapV3Pool pool;
    IUniswapV3Factory factory;
    UniswapPoorOracle oracle;

    function setUp() public {
        // deploy contracts
        tokenA = new TestERC20();
        tokenB = new TestERC20();
        oracle = new UniswapPoorOracle(IN_RANGE_THRESHOLD, RECORDING_MIN_LENGTH, RECORDING_MAX_LENGTH);
        factory = IUniswapV3Factory(deployUniswapV3Factory());
        pool = IUniswapV3Pool(factory.createPool(address(tokenA), address(tokenB), FEE));
        pool.initialize(TickMath.getSqrtRatioAtTick(0));
        vm.label(address(pool), "UniswapV3Pool");
        bunniHub = new BunniHub(factory, address(this), 0);
        weth = new WETH();
        router = new SwapRouter(address(factory), address(weth));

        // token approvals
        tokenA.approve(address(router), type(uint256).max);
        tokenA.approve(address(bunniHub), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenB.approve(address(bunniHub), type(uint256).max);

        // provide liquidity
        key = BunniKey({pool: pool, tickLower: TICK_LOWER, tickUpper: TICK_UPPER});
        bunniHub.deployBunniToken(key);
        tokenA.mint(address(this), 1e18);
        tokenB.mint(address(this), 1e18);
        bunniHub.deposit(
            IBunniHub.DepositParams({
                key: key,
                amount0Desired: 1e18,
                amount1Desired: 1e18,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(this)
            })
        );
    }

    function test_initialStateShouldBeUnknown() public {
        UniswapPoorOracle.PositionState state = oracle.getPositionState(address(pool), TICK_LOWER, TICK_UPPER);
        assertEq(uint256(state), uint256(UniswapPoorOracle.PositionState.UNKNOWN), "State not UNKNOWN");
    }

    function test_inRangeRecording_inRangeAllTheTime() public {
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
        skip(RECORDING_MIN_LENGTH);
        UniswapPoorOracle.PositionState state = oracle.finishRecording(address(pool), TICK_LOWER, TICK_UPPER);
        assertEq(uint256(state), uint256(UniswapPoorOracle.PositionState.IN_RANGE), "State not IN_RANGE");
    }

    function test_inRangeRecording_inRangePartOfTheTime() public {
        // in range 2/3 of the time
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
        skip(RECORDING_MIN_LENGTH * 2 / 3);

        // make swap to move the price out of range
        uint256 amountIn = 1e20;
        tokenA.mint(address(this), amountIn);
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            fee: FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        router.exactInputSingle(swapParams);
        (, int24 tick,,,,,) = pool.slot0();
        assert(tick > TICK_UPPER || tick < TICK_LOWER);

        // finish recording
        skip(RECORDING_MIN_LENGTH - RECORDING_MIN_LENGTH * 2 / 3);
        UniswapPoorOracle.PositionState state = oracle.finishRecording(address(pool), TICK_LOWER, TICK_UPPER);
        assertEq(uint256(state), uint256(UniswapPoorOracle.PositionState.IN_RANGE), "State not IN_RANGE");
    }

    function test_outOfRangeRecording_outOfRangeAllTheTime() public {
        // create new position to initialize tickLower in the pool
        int24 tickLower = 100;
        int24 tickUpper = 1000;
        tokenA.mint(address(this), 1e18);
        tokenB.mint(address(this), 1e18);
        BunniKey memory k = BunniKey({pool: pool, tickLower: tickLower, tickUpper: tickUpper});
        bunniHub.deployBunniToken(k);
        bunniHub.deposit(
            IBunniHub.DepositParams({
                key: k,
                amount0Desired: 1e18,
                amount1Desired: 1e18,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(this)
            })
        );

        // record
        oracle.startRecording(address(pool), 100, tickUpper);
        skip(RECORDING_MIN_LENGTH);
        UniswapPoorOracle.PositionState state = oracle.finishRecording(address(pool), 100, tickUpper);
        assertEq(uint256(state), uint256(UniswapPoorOracle.PositionState.OUT_OF_RANGE), "State not OUT_OF_RANGE");
    }

    function test_outOfRangeRecording_outOfRangePartOfTheTime() public {
        // in range 1/3 of the time
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
        skip(RECORDING_MIN_LENGTH / 3);

        // make swap to move the price out of range
        uint256 amountIn = 1e20;
        tokenA.mint(address(this), amountIn);
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            fee: FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        router.exactInputSingle(swapParams);
        (, int24 tick,,,,,) = pool.slot0();
        assert(tick > TICK_UPPER || tick < TICK_LOWER);

        // finish recording
        skip(RECORDING_MIN_LENGTH - RECORDING_MIN_LENGTH / 3);
        UniswapPoorOracle.PositionState state = oracle.finishRecording(address(pool), TICK_LOWER, TICK_UPPER);
        assertEq(uint256(state), uint256(UniswapPoorOracle.PositionState.OUT_OF_RANGE), "State not OUT_OF_RANGE");
    }

    function test_fail_startRecordingTwice() public {
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
        vm.expectRevert(bytes4(keccak256("UniswapPoorOracle__RecordingAlreadyInProgress()")));
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
    }

    function test_fail_finishNonexistentRecording() public {
        vm.expectRevert(bytes4(keccak256("UniswapPoorOracle__NoValidRecording()")));
        oracle.finishRecording(address(pool), TICK_LOWER, TICK_UPPER);
    }

    function test_fail_finishRecordingEarly() public {
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
        skip(RECORDING_MIN_LENGTH - 1);
        vm.expectRevert(bytes4(keccak256("UniswapPoorOracle__NoValidRecording()")));
        oracle.finishRecording(address(pool), TICK_LOWER, TICK_UPPER);
    }

    function test_fail_finishRecordingLate() public {
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
        skip(RECORDING_MAX_LENGTH + 1);
        vm.expectRevert(bytes4(keccak256("UniswapPoorOracle__NoValidRecording()")));
        oracle.finishRecording(address(pool), TICK_LOWER, TICK_UPPER);
    }
}
