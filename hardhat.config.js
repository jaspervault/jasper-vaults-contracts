require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-tracer");
require('@typechain/hardhat')
require('@nomicfoundation/hardhat-ethers')
require('@nomicfoundation/hardhat-chai-matchers')
require("dotenv").config();


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.12",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: "0.8.9",
        settings: { optimizer: { enabled: true, runs: 200 } },
      }
    ]
  },
  networks: {
    arbitrum: {
      url: "https://arbitrum.blockpi.network/v1/rpc/public",
      accounts: [`${process.env.PK}`],
    }
  },
  etherscan: {
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
  },
  typechain: {
    outDir: './dist',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: [], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
    dontOverrideCompile: false
  },
};
