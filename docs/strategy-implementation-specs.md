# Strategy implementation specs
The interfaces mention `position` often, this argument is there for protocols where users can have multiple positions, strategies are free to use any values for this argument as long as it always refers to the same position.

If a user is never able to have more than a single position for a strategy (because the underlying protocol only support a single position) then the strategy should use `IUWConstants.SINGLE_POSITON` to represent this position.

### Deposit
For deposit there are three interfaces, `IUWDeposit`, `IUWDepositBeneficiary` and `IUWDepositExtended`. All strategies should strive to implement `IUWDeposit` and if possible also `IUWDepositBeneficiary`, in cases where this is not possible or would have serious downsides its possible to implement the alternative `IUWDepositExtended`.

The deposit event should emit an `TrackPosition` event if its likely this was the first interaction with this position, however this is not required. This event allows the UI to more easily discover what positions the user has.

### Withdraw
For deposits there is `IUWWithdraw` and `IUWWithdrawExtended`. All strategies should try and implement `IUWWithdraw`, if thats not possible or would have serious downsides it can implement the alternative 'IUWWithdrawExtended`.

### Borrow
For deposits there is `IUWBorrow` and `IUWBorrowExtended`. All strategies should try and implement `IUWBorrow`, if thats not possible or would have serious downsides it can implement the alternative 'IUWBorrowExtended`.

## Reports
These interfaces expose view methods that may be implemented by strategies. These methods can expect to always be called through a RPC call and never in a transaction.

### Assets & Debt
The `IUWAssetReport` is used to report assets that belong to the user but are not in the users wallet, such as a deposit into a yield farm. 

A simple example is a user that uses a strategy to deposit 100 DAI into a yield farm, the `assets(...)` should report back `100 DAI`.

However in the case where a strategy deposits in a yield farm and the deposit contract gives the user a token (lets call it `yDAI`) to represent the deposit it becomes (only slightly) more complex. In this case the strategy should also implement a `IUWDebtReport`.
This `IUWDebtReport.debt(...)` should return `100 yDAI`.

This is to prevent a wallet from seeing the `yDAI` and calculating a price for it and then adding the `assets(...)` to it. This would result in double counting some of the users assets.

Another usecase for `IUWAssetReport` and `IUWDebtReport` is of course lending markets, where the user might have `100 DAI` as colleteral and a debt of `20 USDT`.

### Debt Health
The `IUWDebtHealthReport` can be implemented to report the health of positions in a strategy, but only if the positions in the strategy can be liquidated because of rising debt *OR* the user is able to take out debt but does *NOT* include strategies where the user receives a token as a certificate of deposit but is not able to receive more assets or be liquidated. 

Some examples of when to implement this:
- ✅Lending market (even if a user can't be liquidated)
- ✅Leveraged trading
- ✅Leveraged yield farm
- ❌Yield farm

The returned `current` value should be 0 if a user has only deposited colleteral but has not taken out a loan. As the user takes out more debt (or their colleteral assets decrease in value compared to the debt) the `current` value should increase. The `max` variable represents the maximum amount of debt the user is able to take out, the `liquidatable` represents at what point the user risks getting liquidated. A strategy can use any denomination for these values but should attempt to return the denomination used by the protocol (ex USD, EUR, ETH).

Some examples of denominations:
- current $100, max $175, liquidatable $250 (prefered)
- current 40%, max 70%, liquidatable 100%
