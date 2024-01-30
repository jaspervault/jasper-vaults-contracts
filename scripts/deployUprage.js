
const { ethers,upgrades,run} = require('hardhat');
const network = process.env.HARDHAT_NETWORK
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));

var contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
async function main() {
    let contractName = "OptionMoudle"
    // await upgrades.forceImport(contractData[contractName], await ethers.getContractFactory(contractName))
    await upgradeProxyContract(contractName, contractData[contractName], { kind: "uups", redeployImplementation: "always" })
    console.log(`<deployUprage ${contractName} done>`)
}


async function upgradeProxyContract(contractName,contractAddress,verify,...args){
    const Contract = await ethers.getContractFactory(contractName);
    const contract = await upgrades.upgradeProxy(contractAddress, Contract,{kind:"uups",redeployImplementation:"always"});
    console.log("<" + contractName + "> contract address: ", contractAddress + " hash: " + contract.deployTransaction.hash);
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
}
main().catch((error) => {
    console.error(error);
    // process.exitCode = 1;
});
  