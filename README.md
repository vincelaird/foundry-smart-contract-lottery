# Decentralized Raffle Smart Contract

This project implements a decentralized raffle system using Chainlink VRF for secure random number generation and Chainlink Automation for automated winner selection.

Based on Patrick Collins [Foundry Smart Contract Lottery lesson.](https://github.com/Cyfrin/foundry-smart-contract-lottery-cu)

## Overview

The Raffle smart contract allows users to enter a lottery by paying an entrance fee. After a set interval, the contract uses Chainlink VRF to select a winner randomly and fairly. The winner receives the entire prize pool.

## Features

- Decentralized and transparent lottery system
- Chainlink VRF integration for verifiable random number generation
- Automated winner selection using Chainlink Automation
- Configurable entrance fee and raffle interval

## Tools and Technologies

- Solidity
- Foundry (Forge, Cast, Anvil)
- Chainlink VRF and Automation

## Test Coverage (as of 2024-08-30)

| File                      | % Lines         | % Statements     | % Branches     | % Funcs        |
|---------------------------|-----------------|------------------|----------------|----------------|
| script/DeployRaffle.s.sol | 93.75% (15/16)  | 95.00% (19/20)   | 100.00% (1/1)  | 50.00% (1/2)   |
| script/HelperConfig.s.sol | 93.75% (15/16)  | 89.47% (17/19)   | 80.00% (4/5)   | 100.00% (5/5)  |
| script/Interactions.s.sol | 81.82% (36/44)  | 81.48% (44/54)   | 100.00% (2/2)  | 77.78% (7/9)   |
| src/Raffle.sol            | 81.08% (30/37)  | 81.25% (39/48)   | 75.00% (3/4)   | 80.00% (8/10)  |
| test/mocks/LinkToken.sol  | 0.00% (0/12)    | 0.00% (0/13)     | 0.00% (0/1)    | 0.00% (0/5)    |
| Total                     | 76.80% (96/125) | 77.27% (119/154) | 76.92% (10/13) | 67.74% (21/31) |

## Usage

### Build

To build the project, run:

```bash
forge build
```

### Test

To run the tests, run:

```bash
forge test
```

### Format

To format the code, run:

```bash
forge fmt
```

### Gas Snapshots

To get gas snapshots, run:

```bash
forge snapshot
```

### Anvil

To start anvil, run:

```bash
anvil
```

### Deploy

To deploy the contract, run:

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url <your_rpc_url> --private-key <your_private_key>
```

As an example, to deploy the contract on Sepolia, you can use:

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url https://sepolia.infura.io/v3/YOUR_PROJECT_ID --broadcast --verify --etherscan-api-key <your_etherscan_api_key> --account <your_keystore_name> -vvvv
```

Note, remove verify and etherscan-api-key if the command above fails.
This also requires proper setup of a VRF subscription ID and key on Sepolia.

### Cast

To interact with the contract, you can use cast:

```bash
cast <subcommand>
```

### Help

To get help, run:

```bash
forge --help
anvil --help
cast --help
```

## Documentation

For more detailed information about Foundry's capabilities, visit the [Foundry Book](https://book.getfoundry.sh/).

## License

This project is licensed under the [MIT License](LICENSE).