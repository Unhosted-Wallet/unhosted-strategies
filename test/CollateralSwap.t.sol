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
    USDC_TOKEN,
    COMPOUND_V3_COMET_USDC,
    WRAPPED_NATIVE_TOKEN,
    WBTC,
    UNISWAPV3_ROUTER,
    UNISWAPV3_FACTORY,
    AWRAPPED_NATIVE_V2_DEBT_VARIABLE,
    AWRAPPED_NATIVE_V2_TOKEN
} from "test/utils/constant_eth.sol";

import {UserOperation, IAccount} from "I4337/interfaces/IAccount.sol";
import {IUniswapV3Factory} from "test/interfaces/IUniswapV3Factory.sol";
import {IComet} from "test/interfaces/IComet.sol";

import {StrategyModuleFactory} from "src/StrategyModule/StrategyFactory.sol";
import {ILendingPoolAddressesProviderV2} from "@unhosted/handlers/aaveV2/ILendingPoolAddressesProviderV2.sol";
import {ILendingPoolV2} from "@unhosted/handlers/aaveV2/ILendingPoolV2.sol";
import {StrategyModule, IStrategyModule} from "src/StrategyModule/StrategyModule.sol";

import "src/mocks/MockERC20.sol";
import "forge-std/console.sol";

import {CompV3CollateralSwap} from "src/CollateralSwap/CompV3CollateralSwapH.sol";
import {FlashloanCallbackHandler} from "src/CollateralSwap/CompV3CallbackHandler.sol";

contract CollateralSwap is BiconomyTest {
    SmartAccountFactory factory;
    StrategyModule stratModule;
    StrategyModuleFactory stratFactory;
    ILendingPoolAddressesProviderV2 aaveV2Provider;
    ILendingPoolV2 lendingPool;
    IUniswapV3Factory uniV3Factory;
    IComet usdcComet;
    MockERC20 WETH;

    FlashloanCallbackHandler callback;
    CompV3CollateralSwap handler;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() external {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        initializeTest();
        factory = SmartAccountFactory(BCNMY_FACTORY);
        vm.etch(BCNMY_FACTORY, BCNMY_FACTORY_BYTECODE);
        vm.etch(BCNMY_IMPL, BCNMY_IMPL_BYTECODE);
        setAccount();

        stratModule = new StrategyModule();
        stratFactory = new StrategyModuleFactory(address(stratModule));
        aaveV2Provider = ILendingPoolAddressesProviderV2(AAVEPROTOCOL_V2_PROVIDER);
        lendingPool = ILendingPoolV2(aaveV2Provider.getLendingPool());

        callback = new FlashloanCallbackHandler(UNISWAPV3_ROUTER, WRAPPED_NATIVE_TOKEN);
        handler = new CompV3CollateralSwap(
            WRAPPED_NATIVE_TOKEN, AAVEPROTOCOL_V2_PROVIDER, address(callback)
        );

        stratModule = StrategyModule(payable(stratFactory.deployStrategyModule(beneficiary, address(handler), 0)));

        createAccount(owner);
        UserOperation memory op = fillUserOp(
            fillData(
                address(account), 0, abi.encodeWithSelector(SmartAccount.enableModule.selector, address(stratModule))
            )
        );
        executeUserOp(op, "enableModule", 0);
        uniV3Factory = IUniswapV3Factory(UNISWAPV3_FACTORY);
        WETH = MockERC20(WRAPPED_NATIVE_TOKEN);
        usdcComet = IComet(COMPOUND_V3_COMET_USDC);
    }

    function testEnableModule() external {
        assertEq(SmartAccount(address(account)).isModuleEnabled(address(stratModule)), true);
    }

    function testSingleAssetNoDebt() external {
        uint256 value = 100e18;
        uint256 loanFee = (value * 9) / 1e4;
        address provider = uniV3Factory.getPool(USDC_TOKEN, WRAPPED_NATIVE_TOKEN, 500);
        vm.startPrank(provider);
        WETH.approve(COMPOUND_V3_COMET_USDC, value);
        WETH.transfer(address(account), loanFee);
        usdcComet.supplyTo(address(account), WRAPPED_NATIVE_TOKEN, value);
        vm.stopPrank();

        bytes memory data = abi.encodeWithSelector(
            handler.collateralSwap.selector, COMPOUND_V3_COMET_USDC, WRAPPED_NATIVE_TOKEN, WBTC, value, 0
        );
        uint256 gas = 3e6;
        bytes32 hash = stratModule.getTransactionHash(
            IStrategyModule.StrategyTransaction(0, gas, data), stratModule.getNonce(address(account)), address(account)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 wethBefore = usdcComet.collateralBalanceOf(address(account), WRAPPED_NATIVE_TOKEN);
        uint256 wbtcBefore = usdcComet.collateralBalanceOf(address(account), WBTC);

        stratModule.execStrategy(address(account), IStrategyModule.StrategyTransaction(0, gas, data), signature);

        uint256 wethAfter = usdcComet.collateralBalanceOf(address(account), WRAPPED_NATIVE_TOKEN);
        uint256 wbtcAfter = usdcComet.collateralBalanceOf(address(account), WBTC);

        console.log("weth collateral before :", wethBefore);
        console.log("wbtc collateral before :", wbtcBefore);
        console.log("weth collateral after  :", wethAfter);
        console.log("wbtc collateral after  :", wbtcAfter);

        assertEq(wethBefore - wethAfter, value);
        assertEq(wbtcBefore, 0);
        assertGt(wbtcAfter, 0);
    }

    function testSingleAssetVariableDebt() external {
        uint256 depositAmount = 1000e18;
        address provider = uniV3Factory.getPool(USDC_TOKEN, WRAPPED_NATIVE_TOKEN, 500);
        uint256 value = 100e18;
        vm.startPrank(provider);
        WETH.approve(COMPOUND_V3_COMET_USDC, value);
        WETH.approve(aaveV2Provider.getLendingPool(), depositAmount);
        lendingPool.deposit(WRAPPED_NATIVE_TOKEN, depositAmount, address(account), 0);
        usdcComet.supplyTo(address(account), WRAPPED_NATIVE_TOKEN, value);
        vm.stopPrank();

        bytes memory data = abi.encodeWithSelector(
            handler.collateralSwap.selector, COMPOUND_V3_COMET_USDC, WRAPPED_NATIVE_TOKEN, WBTC, value, 2, 0
        );
        uint256 gas = 3e6;
        bytes32 hash = stratModule.getTransactionHash(
            IStrategyModule.StrategyTransaction(0, gas, data), stratModule.getNonce(address(account)), address(account)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 awethDebtBefore = MockERC20(AWRAPPED_NATIVE_V2_DEBT_VARIABLE).balanceOf(address(account));
        uint256 wethBefore = usdcComet.collateralBalanceOf(address(account), WRAPPED_NATIVE_TOKEN);
        uint256 wbtcBefore = usdcComet.collateralBalanceOf(address(account), WBTC);
        uint256 awethBalance = MockERC20(AWRAPPED_NATIVE_V2_TOKEN).balanceOf(address(account));

        stratModule.execStrategy(address(account), IStrategyModule.StrategyTransaction(0, gas, data), signature);

        uint256 awethDebtAfter = MockERC20(AWRAPPED_NATIVE_V2_DEBT_VARIABLE).balanceOf(address(account));
        uint256 wethAfter = usdcComet.collateralBalanceOf(address(account), WRAPPED_NATIVE_TOKEN);
        uint256 wbtcAfter = usdcComet.collateralBalanceOf(address(account), WBTC);

        console.log("aweth balance before   :", awethDebtBefore);
        console.log("weth collateral before :", wethBefore);
        console.log("wbtc collateral before :", wbtcBefore);
        console.log("aweth balance after    :", awethDebtAfter);
        console.log("weth collateral after  :", wethAfter);
        console.log("wbtc collateral after  :", wbtcAfter);

        assertEq(awethBalance, 1000e18);
        assertEq(wethBefore - wethAfter, 100e18);
        assertEq(awethDebtAfter - awethDebtBefore, 100e18);
        assertEq(wbtcBefore, 0);
        assertEq(awethDebtBefore, 0);
        assertGt(wbtcAfter, 0);
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
