
const { ethers,upgrades,run } = require('hardhat');
const hre = require('hardhat');

async function main() {
  var   [deployer]=await ethers.getSigners();
      await run("verify:verify", {
        address: "0x7A15730F3a188A8d7c2C66Fec428DFf4155F6eF3",
        constructorArguments:[],
        // constructorArguments:["0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"],
        // constructorArguments:[ethers.constants.AddressZero,"0x"]
        // constructorArguments:[deployer.address,"0x"]
        // libraries:{
        // }
      });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
