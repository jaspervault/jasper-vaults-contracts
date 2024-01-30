const { ethers,upgrades,run } = require('hardhat');
const network = process.env.HARDHAT_NETWORK
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
var contractData={}
var deployer;
async function main() {

    [deployer]=await ethers.getSigners();
    contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
    await deployProxyContract("LeverageModule",true,contractData.Diamond);
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
  