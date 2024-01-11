require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-tracer");
// require("hardhat-gas-reporter");
// require('@openzeppelin/hardhat-upgrades');
// require("@nomiclabs/hardhat-ganache");
require("dotenv").config();

// const { ProxyAgent, setGlobalDispatcher } = require("undici");
// const proxyAgent = new ProxyAgent('http://127.0.0.1:1081'); // change to yours
// setGlobalDispatcher(proxyAgent);

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity:{
    compilers:[
      {
       version:"0.8.12",
       settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version:"0.8.9",
        settings: { optimizer: { enabled: true, runs: 200 } },
       }
  ]
  },
  networks:{
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    mumbai:{
      url: "https://polygon-mumbai.blockpi.network/v1/rpc/410ce73ca9c8eed378ea7f12ccc75189e04ddc77",
      accounts: [`${process.env.PK}`],
      gasPrice:2000000000
    },
    goerli:{
      url:"https://goerli.blockpi.network/v1/rpc/public",
      accounts: [`${process.env.PK}`],
      gasPrice:500
    },
    polygon:{
      url:"https://polygon.blockpi.network/v1/rpc/2f4a5449f8f37607cf884bad80c108d3fd7d88b3",
      // url:"https://polygon.blockpi.network/v1/rpc/public",
      // url:"https://polygon.llamarpc.com",
      accounts: [`${process.env.PK}`],
      gasPrice:180000000000
    },
    polygon_uat:{
      // url:"https://polygon.blockpi.network/v1/rpc/public",
      // url:"https://polygon.llamarpc.com",
      // url:"http://192.168.3.30:8545",
      // url:"HTTP://127.0.0.1:7545",
      url:"https://polygon.blockpi.network/v1/rpc/2f4a5449f8f37607cf884bad80c108d3fd7d88b3",
      accounts: [`${process.env.PK}`],
      gasPrice:80000000000
    },
    polygon_uat_dev:{
      // url:"https://polygon.blockpi.network/v1/rpc/public",
      // url:"https://polygon.llamarpc.com",
      url:"https://polygon.blockpi.network/v1/rpc/2f4a5449f8f37607cf884bad80c108d3fd7d88b3",
      accounts: [`${process.env.PK}`],
      gasPrice:110000000000
    },  
    ethereum:{
      // url:"https://ethereum.blockpi.network/v1/rpc/public",
      // url:"https://ethereum.blockpi.network/v1/rpc/08477cf97ef1a6e042db5304ee957d2598d739b5",
      url:"https://eth-mainnet.g.alchemy.com/v2/bCy-dNQogPRmiiArmblIlEn8ViU_ns7D",
      accounts: [`${process.env.PK}`],
      gasPrice:14000000000,
      timeout: 1000000
    },
    sepolia:{
      url:"https://ethereum-sepolia.blockpi.network/v1/rpc/public",
      accounts: [`${process.env.PK}`],
      gasPrice:100000000  
    },
    ethFork:{
      url:"http:/192.168.31.228:8645",
      accounts:[`${process.env.PK}`],
      gasPrice:45000000000,
      timeout: 1000000
    }

  },
  etherscan:{
    //bsc
    // apiKey: "I5ZF72517II2FRPQRRHMWGN7PHCFGD3NNF"
    //eth
    // apiKey: "R3CRF4YGIPI8MH6M37TTQHEH1B5SF4BI63"
    // polygon
    apiKey: "1R2G1HDRWDX9JT1H8BRM8GXT4INUE8CN27"
    //base
    // apiKey: "92575c4a-2830-4a7c-a40f-d7c6ed460934",
    //arbitrum
    //apiKey: "65PSNHIK3HDV9K88DNZQAM9GN8ZVCT288B"
  }
};
