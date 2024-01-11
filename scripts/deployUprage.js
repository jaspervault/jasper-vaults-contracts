
const { ethers,upgrades,run} = require('hardhat');
const network = process.env.HARDHAT_NETWORK
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`)); 
 var contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
async function main() { 
    let contractName="LeverageModule"
    // await upgrades.forceImport(contractData[contractName],await ethers.getContractFactory(contractName))
    await upgradeProxyContract(contractName,contractData[contractName],{kind:"uups",redeployImplementation:"always"})
    console.log(`<deployUprage ${contractName} done>`) 
} 

//升级合约(uups)
async function upgradeProxyContract(contractName,contractAddress,verify,...args){
    const Contract = await ethers.getContractFactory(contractName);
    const contract = await upgrades.upgradeProxy(contractAddress, Contract,{kind:"uups",redeployImplementation:"always"});
    console.log("<" + contractName + "> contract address: ", contractAddress + " hash: " + contract.deployTransaction.hash);
}

main().catch((error) => {
    console.error(error);
    // process.exitCode = 1;
});
  