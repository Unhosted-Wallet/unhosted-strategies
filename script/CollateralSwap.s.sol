// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {CompV3FlashloanCallbackHandler} from "../src/CollateralSwap/CompV3CallbackHandler.sol";
import {CompV3CollateralSwap} from "../src/CollateralSwap/CompV3CollateralSwapH.sol";
import {WRAPPED_NATIVE_TOKEN, UNISWAPV3_ROUTER} from "test/utils/constant_goerli.sol";

contract DeployCSScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        CompV3FlashloanCallbackHandler callback = new CompV3FlashloanCallbackHandler(UNISWAPV3_ROUTER, WRAPPED_NATIVE_TOKEN);

        vm.stopBroadcast();
    }
}
