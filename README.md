# <p align="center"><img src="logo.png" alt="Unhosted" height="100px"></p>

# Strategies

# Defi Strategy Handlers

This library includes DeFi protocol strategies. It undergoes continuous updates, expanding its functionality by incorporating new protocols and automated DeFi strategies. [Unhosted Strategy Module](https://github.com/Unhosted-Wallet/unhosted-modules/tree/main/strategy-module)

<<<<<<< HEAD
## Overview
=======
- [Compound v3 Collateral Swap](./src/CollateralSwap/CompV3CollateralSwapH.sol)
- [Aave v2 Collateral Swap](./src/CollateralSwap/AaveV2CollateralSwapH.sol)
- [Aave v2 Debt Swap](./src/DebtSwap/AaveV2DebtSwapH.sol)
>>>>>>> main

### Installation

#### Hardhat, Truffle (npm)

```
$ npm install @unhosted/strategies  @openzeppelin/contracts
```

#### Foundry (git)

```
$ forge install Unhosted-Wallet/unhosted-strategies OpenZeppelin/openzeppelin-contracts
```

Also add  
```
$ @unhosted/strategies/=lib/unhosted-strategies/src/  
$ @openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
```
to `remappings.txt`

### Usage

<em>If you're new to smart contract development, head to [Developing Smart Contracts](https://docs.openzeppelin.com/learn/developing-smart-contracts) by openzeppelin to learn about creating a new project and compiling your contracts</em>.

After installation, you have the flexibility to utilize the strategies by importing them. You can either build upon existing defi protocol strategies or create your own by inheriting from `BaseStrategy`. After constructing and deploying your strategy, add it to the Unhosted StrategyModule using the updateStrategy function. This makes your strategy accessible to all Unhosted users, allowing them to execute it and rewarding you with execution fees:

```solidity
pragma solidity ^0.8.20;

import { UniswapV3Strategy } from "@unhosted/strategies/uniswapV3/UniswapV3Strategy.sol";
import { AaveV2Strategy } from "@unhosted/strategies/aaveV2/AaveV2Strategy.sol";

contract MyStrategy is UniswapV3Strategy, AaveV2Strategy {
  constructor(
    address wethAddress,
    address aaveV2Provider,
    address fallbackHandler
  )
    UniswapV3Strategy(wethAddress)
    AaveV2Strategy(wethAddress, aaveV2Provider, fallbackHandler)
  {}

  function getStrategyName()
    public
    pure
    override(UniswapV3Strategy, AaveV2Strategy)
    returns (string memory)
  {
    return "MyStrategy";
  }
}
```

> [!IMPORTANT]
>
> 1. The strategy function can execute via `call` or `delegatecall` from the user's smart account. When using `delegatecall`, it's essential for strategies to prioritize security considerations and avoid modifying the SA's storage.
> 2. For functionalities requiring changes in the fallback handler, such as flashloans, the fallback manager slot is accessible in `BaseStrategy`. This slot can be temporarily updated to execute the desired logic.

## Contribution

We welcome contributions to this repository. If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.

## License

All smart contracts are released under MIT

## Documentation

https://docs.unhosted.com/
