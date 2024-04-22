# JasperVault V2

# Jasper Vaults Contracts

Jasper Vaults Contracts is a decentralized options project based on Ethereum.

## Table of Contents

* [Installation](#installation)
* [Testing](#testing)
* [Deployment](#deployment)
* [Contribution](#contribution)

## Installation

First, you need to install [Node.js](https://nodejs.org/) with the node and npm versions in line with the following requirements:

* Node.js: 16.x or higher
* npm: 6.x or higher

Then, you can use npm to install the dependencies of the project:

```
npm install

```

## Testing

This project uses Hardhat for testing. First, you need to create a `.env` file and set your Ethereum node address. Then, you can run the following command for testing:

```
npx hardhat test

```

## Deployment

First, you need to set your private key and Ethereum node address in the `.env` file. Then, you can run the following command for deployment:

```
npx hardhat run scripts/deploy.js --network mainnet

```

## Contribution

We welcome contributions from everyone. If you have any questions or suggestions, please create an issue or submit a pull request on GitHub.
