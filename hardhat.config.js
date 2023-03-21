require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
// const { ProxyAgent, setGlobalDispatcher } = require("undici");
// const proxyAgent = new ProxyAgent('http://127.0.0.1:1081'); // change to yours
// setGlobalDispatcher(proxyAgent);


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.4.18",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: "0.6.10",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: "0.6.12",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },

      {
        version: "0.8.0",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },

      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.12",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      { version: "0.8.6", settings: { optimizer: { enabled: true, runs: 200 } }, }
    ],
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      timeout: 200000,
      gas: 12000000,
      blockGasLimit: 12000000
    },
    mainnet: {
      url: "https://mainnet.infura.io/v3/98904658bc4043d49e602fd1ba345f8a",
      accounts: [`${process.env.ETHEREUM_DEPLOY_PRIVATE_KEY}`],
    },
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_TOKEN}`,
      accounts: [`${process.env.PRODUCTION_MAINNET_DEPLOY_PRIVATE_KEY}`],

    },
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2/" + process.env.ALCHEMY_TOKEN,
      accounts: [`${process.env.PRODUCTION_MAINNET_DEPLOY_PRIVATE_KEY}`],
    },
    coverage: {
      url: "http://127.0.0.1:8555", // Coverage launches its own ganache-cli client
      timeout: 200000,
    },
  },
  etherscan: {
    //bsc
    // apiKey: "I5ZF72517II2FRPQRRHMWGN7PHCFGD3NNF"
    //eth
    //apiKey: "R3CRF4YGIPI8MH6M37TTQHEH1B5SF4BI63"
    //polygon
    //apiKey: "1R2G1HDRWDX9JT1H8BRM8GXT4INUE8CN27"
    //base
    apiKey: "92575c4a-2830-4a7c-a40f-d7c6ed460934",
    customChains: [
      {
        network: "base-goerli",
        chainId: 84531,
        urls: {
          // Pick a block explorer and uncomment those lines

          // Blockscout
          // apiURL: "https://base-goerli.blockscout.com/api",
          // browserURL: "https://base-goerli.blockscout.com"

          //Basescan by Etherscan
          apiURL: "https://api-goerli.basescan.org/api",
          browserURL: "https://goerli.basescan.org"
        }
      }
    ]
  },
};
