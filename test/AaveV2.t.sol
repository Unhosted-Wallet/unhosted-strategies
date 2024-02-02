pragma solidity ^0.8.0;

import {BiconomyTest} from "test/BiconomyTest.t.sol";
import {
    BCNMY_IMPL,
    BCNMY_IMPL_BYTECODE,
    BCNMY_FACTORY,
    BCNMY_FACTORY_BYTECODE,
    SmartAccountFactory,
    SmartAccount
} from "test/artifacts/BcnmyArtifacts.sol";
import {
    AAVEPROTOCOL_V2_PROVIDER,
    USDC,
    AUSDC_V2_DEBT_STABLE,
    AUSDC_V2_DEBT_VARIABLE,
    WRAPPED_NATIVE_TOKEN,
    WBTC,
    AWBTC_V2,
    AWBTC_V2_DEBT_STABLE,
    AWBTC_V2_DEBT_VARIABLE,
    UNISWAPV3_ROUTER,
    UNISWAPV3_FACTORY,
    AWRAPPED_NATIVE_V2_DEBT_VARIABLE,
    AWRAPPED_NATIVE_V2_DEBT_STABLE,
    AWRAPPED_NATIVE_V2_TOKEN,
    AAVE_DATA_PROVIDER_V2,
    UNISWAPV3_QUOTER
} from "test/utils/constant_eth.sol";

import {UserOperation, IAccount} from "I4337/interfaces/IAccount.sol";
import {IUniswapV3Factory} from "test/interfaces/IUniswapV3Factory.sol";

import {ILendingPoolAddressesProviderV2} from "src/aaveV2/helpers/ILendingPoolAddressesProviderV2.sol";
import {ILendingPoolV2} from "src/aaveV2/helpers/ILendingPoolV2.sol";
import {StrategyModule, IStrategyModule, Enum} from "src/StrategyModule/StrategyModule.sol";

import "solady/tokens/ERC20.sol";
import "forge-std/console.sol";

import {AaveV2Strategy} from "src/aaveV2/AaveV2Strategy.sol";
import {AaveV2FallbackHandler} from "src/aaveV2/FallbackHandler.sol";

contract AaveV2 is BiconomyTest {
    SmartAccountFactory factory;
    StrategyModule stratModule;
    ILendingPoolAddressesProviderV2 aaveV2Provider;
    ILendingPoolV2 lendingPool;
    IUniswapV3Factory uniV3Factory;
    ERC20 WETH;
    ERC20 USDC_TOKEN;

    AaveV2FallbackHandler fallbackAave2;
    AaveV2Strategy aave2Strat;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() external {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17_679_300);
        initializeTest();
        factory = SmartAccountFactory(BCNMY_FACTORY);
        vm.etch(BCNMY_FACTORY, BCNMY_FACTORY_BYTECODE);
        vm.etch(BCNMY_IMPL, BCNMY_IMPL_BYTECODE);
        setAccount();

        aaveV2Provider = ILendingPoolAddressesProviderV2(AAVEPROTOCOL_V2_PROVIDER);
        lendingPool = ILendingPoolV2(aaveV2Provider.getLendingPool());

        fallbackAave2 = new AaveV2FallbackHandler(UNISWAPV3_ROUTER);

        aave2Strat = new AaveV2Strategy(
            WRAPPED_NATIVE_TOKEN,
            AAVEPROTOCOL_V2_PROVIDER,
            address(fallbackAave2),
            AAVE_DATA_PROVIDER_V2,
            UNISWAPV3_QUOTER
        );

        stratModule =
            new StrategyModule("StrategyModule", "0.2.0");

        createAccount(owner);

        UserOperation memory op = fillUserOp(
            fillData(
                address(account),
                0,
                abi.encodeWithSelector(SmartAccount.enableModule.selector, address(stratModule))
            )
        );
        executeUserOp(op, "enableModule", 0);

        stratModule.updateStrategy(address(aave2Strat), owner);

        uniV3Factory = IUniswapV3Factory(UNISWAPV3_FACTORY);
        WETH = ERC20(WRAPPED_NATIVE_TOKEN);
        USDC_TOKEN = ERC20(USDC);
    }

    function testEnableModule() external {
        assertEq(SmartAccount(address(account)).isModuleEnabled(address(stratModule)), true);
    }

    function testDebtSwapSingleAssetNoDebtAave2StableRate() external {
        uint256 value = 100e18;
        uint256 valueToSwap = 1000e6;
        uint256 loanFee = (valueToSwap * 9) / 1e4;
        address provider = uniV3Factory.getPool(USDC, WRAPPED_NATIVE_TOKEN, 500);
        vm.startPrank(provider);
        WETH.approve(address(lendingPool), value);
        USDC_TOKEN.transfer(address(account), loanFee);
        lendingPool.deposit(WRAPPED_NATIVE_TOKEN, value, address(account), 0);
        vm.stopPrank();

        UserOperation memory op = fillUserOp(
            fillData(
                address(lendingPool),
                0,
                abi.encodeWithSelector(ILendingPoolV2.borrow.selector, USDC, 1000e6, 1, 0, address(account))
            )
        );
        executeUserOp(op, "borrowStable", 0);
        
        bytes memory data = abi.encodeWithSelector(aave2Strat.debtSwap.selector, USDC, WBTC, valueToSwap, 1, 1, 0);
        uint256 gas = 3e6;
        bytes32 hash = stratModule.getStrategyTxHash(
            IStrategyModule.StrategyTransaction(Enum.Operation.DelegateCall, address(aave2Strat), 0, data),
            stratModule.getNonce(address(account))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 awethBefore = ERC20(AWRAPPED_NATIVE_V2_TOKEN).balanceOf(address(account));
        uint256 debtUsdcBefore = ERC20(AUSDC_V2_DEBT_STABLE).balanceOf(address(account));
        uint256 debtWbtcBefore = ERC20(AWBTC_V2_DEBT_STABLE).balanceOf(address(account));

        stratModule.executeStrategy(address(account), IStrategyModule.StrategyTransaction(Enum.Operation.DelegateCall, address(aave2Strat), 0, data), signature);

        uint256 awethAfter = ERC20(AWRAPPED_NATIVE_V2_TOKEN).balanceOf(address(account));
        uint256 debtUsdcAfter = ERC20(AUSDC_V2_DEBT_STABLE).balanceOf(address(account));
        uint256 debtWbtcAfter = ERC20(AWBTC_V2_DEBT_STABLE).balanceOf(address(account));

        console.log("collateral before:", awethBefore);
        console.log("usdc debt before :", debtUsdcBefore);
        console.log("wbtc debt before :", debtWbtcBefore);
        console.log("collateral after :", awethAfter);
        console.log("usdc debt after  :", debtUsdcAfter);
        console.log("wbtc debt after  :", debtWbtcAfter);

        assertEq(awethBefore, awethAfter);
        assertEq(debtWbtcBefore, 0);
        assertEq(debtUsdcBefore, 1000e6);
        assertEq(debtUsdcAfter, 0);
        assertGt(debtWbtcAfter, 0);
    }

    function testDebtSwapSingleAssetNoDebtAave2VariableRate() external {
        uint256 value = 100e18;
        uint256 valueToSwap = 500e6;
        uint256 loanFee = (valueToSwap * 9) / 1e4;
        address provider = uniV3Factory.getPool(USDC, WRAPPED_NATIVE_TOKEN, 500);
        vm.startPrank(provider);
        WETH.approve(address(lendingPool), value);
        USDC_TOKEN.transfer(address(account), loanFee);
        lendingPool.deposit(WRAPPED_NATIVE_TOKEN, value, address(account), 0);
        vm.stopPrank();

        UserOperation memory op = fillUserOp(
            fillData(
                address(lendingPool),
                0,
                abi.encodeWithSelector(ILendingPoolV2.borrow.selector, USDC, 1000e6, 2, 0, address(account))
            )
        );
        executeUserOp(op, "borrowVariable", 0);

        bytes memory data = abi.encodeWithSelector(aave2Strat.debtSwap.selector, USDC, WBTC, valueToSwap, 2, 2, 0);
        uint256 gas = 3e6;
        bytes32 hash = stratModule.getStrategyTxHash(
            IStrategyModule.StrategyTransaction(Enum.Operation.DelegateCall, address(aave2Strat), 0, data),
            stratModule.getNonce(address(account))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 awethBefore = ERC20(AWRAPPED_NATIVE_V2_TOKEN).balanceOf(address(account));
        uint256 debtUsdcBefore = ERC20(AUSDC_V2_DEBT_VARIABLE).balanceOf(address(account));
        uint256 debtWbtcBefore = ERC20(AWBTC_V2_DEBT_VARIABLE).balanceOf(address(account));

        stratModule.executeStrategy(address(account), IStrategyModule.StrategyTransaction(Enum.Operation.DelegateCall, address(aave2Strat), 0, data), signature);

        uint256 awethAfter = ERC20(AWRAPPED_NATIVE_V2_TOKEN).balanceOf(address(account));
        uint256 debtUsdcAfter = ERC20(AUSDC_V2_DEBT_VARIABLE).balanceOf(address(account));
        uint256 debtWbtcAfter = ERC20(AWBTC_V2_DEBT_VARIABLE).balanceOf(address(account));

        console.log("collateral before:", awethBefore);
        console.log("usdc debt before :", debtUsdcBefore);
        console.log("wbtc debt before :", debtWbtcBefore);
        console.log("collateral after :", awethAfter);
        console.log("usdc debt after  :", debtUsdcAfter);
        console.log("wbtc debt after  :", debtWbtcAfter);

        assertEq(awethBefore, awethAfter);
        assertEq(debtWbtcBefore, 0);
        assertEq(debtUsdcBefore, 1000e6);
        assertApproxEqRel(debtUsdcAfter, 500e6, 0.2e10);
        assertGt(debtWbtcAfter, 0);
    }

    function testCollateralSwapSingleAssetNoDebtAave2() external {
        uint256 value = 100e18;
        uint256 loanFee = (value * 9) / 1e4;
        address provider = uniV3Factory.getPool(USDC, WRAPPED_NATIVE_TOKEN, 500);
        vm.startPrank(provider);
        WETH.approve(address(lendingPool), value);
        WETH.transfer(address(account), loanFee);
        lendingPool.deposit(WRAPPED_NATIVE_TOKEN, value, address(account), 0);
        vm.stopPrank();

        bytes memory data =
            abi.encodeWithSelector(aave2Strat.collateralSwap.selector, WRAPPED_NATIVE_TOKEN, WBTC, value, 0);
        uint256 gas = 3e6;
        bytes32 hash = stratModule.getStrategyTxHash(
            IStrategyModule.StrategyTransaction(Enum.Operation.DelegateCall, address(aave2Strat), 0, data),
            stratModule.getNonce(address(account))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 awethBefore = ERC20(AWRAPPED_NATIVE_V2_TOKEN).balanceOf(address(account));
        uint256 awbtcBefore = ERC20(AWBTC_V2).balanceOf(address(account));

        stratModule.executeStrategy(address(account), IStrategyModule.StrategyTransaction(Enum.Operation.DelegateCall, address(aave2Strat), 0, data), signature);

        uint256 awethAfter = ERC20(AWRAPPED_NATIVE_V2_TOKEN).balanceOf(address(account));
        uint256 awbtcAfter = ERC20(AWBTC_V2).balanceOf(address(account));

        console.log("aweth collateral before :", awethBefore);
        console.log("awbtc collateral before :", awbtcBefore);
        console.log("aweth collateral after  :", awethAfter);
        console.log("awbtc collateral after  :", awbtcAfter);

        assertEq(awethBefore - awethAfter, value);
        assertEq(awbtcBefore, 0);
        assertGt(awbtcAfter, 0);
    }

    function testCollateralSwapSingleAssetVariableDebtAave2() external {
        uint256 depositAmount = 1000e18;
        address provider = uniV3Factory.getPool(USDC, WRAPPED_NATIVE_TOKEN, 500);
        uint256 value = 100e18;
        vm.startPrank(provider);
        WETH.approve(address(lendingPool), depositAmount);
        lendingPool.deposit(WRAPPED_NATIVE_TOKEN, depositAmount, address(account), 0);
        vm.stopPrank();

        bytes memory data =
            abi.encodeWithSelector(aave2Strat.collateralSwap.selector, WRAPPED_NATIVE_TOKEN, WBTC, value, 2);
        uint256 gas = 3e6;
        bytes32 hash = stratModule.getStrategyTxHash(
            IStrategyModule.StrategyTransaction(Enum.Operation.DelegateCall, address(aave2Strat), 0, data), stratModule.getNonce(address(account))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 awethDebtBefore = ERC20(AWRAPPED_NATIVE_V2_DEBT_VARIABLE).balanceOf(address(account));
        uint256 awethBefore = ERC20(AWRAPPED_NATIVE_V2_TOKEN).balanceOf(address(account));
        uint256 awbtcBefore = ERC20(AWBTC_V2).balanceOf(address(account));

        stratModule.executeStrategy(address(account), IStrategyModule.StrategyTransaction(Enum.Operation.DelegateCall, address(aave2Strat), 0, data), signature);

        uint256 awethDebtAfter = ERC20(AWRAPPED_NATIVE_V2_DEBT_VARIABLE).balanceOf(address(account));
        uint256 awethAfter = ERC20(AWRAPPED_NATIVE_V2_TOKEN).balanceOf(address(account));
        uint256 awbtcAfter = ERC20(AWBTC_V2).balanceOf(address(account));

        console.log("aweth balance before   :", awethDebtBefore);
        console.log("weth collateral before :", awethBefore);
        console.log("wbtc collateral before :", awbtcBefore);
        console.log("aweth balance after    :", awethDebtAfter);
        console.log("weth collateral after  :", awethAfter);
        console.log("wbtc collateral after  :", awbtcAfter);

        assertEq(awethBefore, 1000e18);
        assertEq(awethBefore - awethAfter, 100e18);
        assertEq(awethDebtAfter - awethDebtBefore, 100e18);
        assertEq(awbtcBefore, 0);
        assertEq(awethDebtBefore, 0);
        assertGt(awbtcAfter, 0);
    }

    function createAccount(address _owner) internal override {
        (bool success, bytes memory data) =
            address(factory).call(abi.encodeWithSelector(factory.deployCounterFactualAccount.selector, _owner, 0));
    }

    function getSignature(UserOperation memory _op) internal view override returns (bytes memory) {
        return signUserOpHash(key, _op);
    }

    function getDummySig(UserOperation memory _op) internal pure override returns (bytes memory) {
        return
        hex"fffffffffffffffffffffffffffffff0000000000000000000000000000000007aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1c";
    }

    function fillData(address _to, uint256 _value, bytes memory _data) internal view override returns (bytes memory) {
        return abi.encodeWithSelector(SmartAccount.executeCall.selector, _to, _value, _data);
    }

    function getAccountAddr(address _owner) internal view override returns (IAccount) {
        (bool success, bytes memory data) = address(factory).staticcall(
            abi.encodeWithSelector(factory.getAddressForCounterFactualAccount.selector, _owner, 0)
        );
        require(success, "getAccountAddr failed");
        return IAccount(abi.decode(data, (address)));
    }

    function getInitCode(address _owner) internal view override returns (bytes memory) {
        return abi.encodePacked(
            address(factory), abi.encodeWithSelector(factory.deployCounterFactualAccount.selector, _owner, 0)
        );
    }
}
