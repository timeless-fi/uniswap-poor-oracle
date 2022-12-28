# Uniswap Poor Oracle

Flashloan-proof Uniswap v3 price-out-of-range oracle for querying if a position is out of range onchain.

Allows anyone to take a recording of a position over a time window to see for what proportion of the window
was the position in range. If the proportion is above the threshold (set at deploy-time) then its state becomes
`IN_RANGE`, otherwise it becomes `OUT_OF_RANGE`.

The security model is thus: in order to manipulate the oracle to falsely give an `IN_RANGE` result for a position, an attacker needs
to keep the price of the pool within the position's range for `inRangeThreshold * recordingLength` seconds of time;
in order to manipulate the oracle to falsely give an `OUT_OF_RANGE` result for a position, an attacker needs
to keep the price of the pool out of the position's range for `(1e18 - inRangeThreshold) * recordingLength` seconds of time. Therefore,
`inRangeThreshold = 0.5` makes it hard to manipulate the oracle in both directions. Also, we can see that the larger `recordingLength` is,
the more secure the resulting state is (in the sense that it's expensive to manipulate), but the more time a recording takes.
In addition, a longer recording is less useful after a point, since the normal volatility of the assets in the pool would come
into play and affect the result, so `recordingLength` should in general be somewhere between 30 minutes and 24 hours.

## Installation

To install with [DappTools](https://github.com/dapphub/dapptools):

```
dapp install timeless-fi/uniswap-poor-oracle
```

To install with [Foundry](https://github.com/gakonst/foundry):

```
forge install timeless-fi/uniswap-poor-oracle
```

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

### Dependencies

```
forge install
```

### Compilation

```
forge build
```

### Testing

```
forge test
```

### Contract deployment

Please create a `.env` file before deployment. An example can be found in `.env.example`.

#### Dryrun

```
forge script script/Deploy.s.sol -f [network]
```

### Live

```
forge script script/Deploy.s.sol -f [network] --verify --broadcast
```