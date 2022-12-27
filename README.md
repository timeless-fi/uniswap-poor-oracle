# Uniswap Poor Oracle

Flashloan-proof Uniswap v3 price-out-of-range oracle for querying if a position is out of range onchain.

Allows anyone to take a recording of a position over a time window to see for what proportion of the window
was the position in range. If the proportion is above the threshold (set at deploy-time) then it's state becomes
`IN_RANGE`, otherwise it becomes `OUT_OF_RANGE`.

## Installation

To install with [DappTools](https://github.com/dapphub/dapptools):

```
dapp install [user]/[repo]
```

To install with [Foundry](https://github.com/gakonst/foundry):

```
forge install [user]/[repo]
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