const { ethers,upgrades,run } = require('hardhat');
const network = process.env.HARDHAT_NETWORK
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
var contractData={}
var deployer;
async function main() {
    [deployer]=await ethers.getSigners();
    // console.log(
    //     "Deploying contracts with the account:",
    //     deployer.address
    // );
    contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
    await deployProxyContract("LeverageModule",true,contractData.Diamond);
    // await deployContract("SimpleAccountFactory",true,settings.entryPoint,"0x6bDaF32E3d75Df303C4ebA6e28749DF8810D62D6");
}






async function deployProxyContract(contractName, verify, ...args) {
    const Contract = await ethers.getContractFactory(contractName);
    var contract = await upgrades.deployProxy(Contract,args);
    console.log("<" + contractName + "> contract address: ", contract.address + " hash: " + contract.deployTransaction.hash);
    contractData[contractName]=contract.address;
    await contract.deployed()
    if (verify) {
        var r = await contract.deployTransaction.wait(settings.safeBlock);
        try {
            await run("verify:verify", {
                address: contract.address,
                // constructorArguments: args,
            });
            console.log("verified contract <" + contractName + "> address:", contract.address);
        } catch (error) {
            console.log(error.message);
            return contract;
        }
    }
    else {
        var r = await contract.deployTransaction.wait(1);
    }
    return contract;
}
async function upgradeProxyContract(contractName,contractAddress,verify,...args){
    const Contract = await ethers.getContractFactory(contractName);
    const contract = await upgrades.upgradeProxy(contractAddress, Contract);
    console.log("<" + contractName + "> contract address: ", contractAddress + " hash: " + contract.hash);
    if (verify) {
      var r = await contract.wait(settings.safeBlock);
      try {
          await run("verify:verify", {
              address: contractAddress,
              constructorArguments: args,
          });
          console.log("verified contract <" + contractName + "> address:",contractAddress);
      } catch (error) {
          console.log(error.message);
      }
      }
      else {
          var r = await contract.wait(1);
      }
}
  
async function deployContract(contractName, verify, ...args){
    const Contract = await ethers.getContractFactory(contractName);
    var contract = await Contract.deploy(...args);
    console.log("<" + contractName + "> contract address: ", contract.address + " hash: " + contract.deployTransaction.hash);
    contractData[contractName]=contract.address;
    await contract.deployed()
    if (verify) {
        var r = await contract.deployTransaction.wait(settings.safeBlock);
        try {
            await run("verify:verify", {
                address: contract.address,
                constructorArguments: args,
            });
            console.log("verified contract <" + contractName + "> address:", contract.address);
        } catch (error) {
            console.log(error.message);
            return contract;
        }
    }
    else {
        var r = await contract.deployTransaction.wait(1);
    }
    return contract;
}



main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  