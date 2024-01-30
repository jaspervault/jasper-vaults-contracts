
const { ethers,upgrades,run } = require('hardhat');
const hre = require('hardhat');

async function main() {
  var   [deployer]=await ethers.getSigners();
      await run("verify:verify", {
        address: "0xf9adAc16e1aE32567E7175c91785B42d6f3929c9",
        // constructorArguments:[],
        constructorArguments:["0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"],
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
