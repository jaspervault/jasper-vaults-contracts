
const { ethers,upgrades,run } = require('hardhat');
const network = process.env.HARDHAT_NETWORK
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
var contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));


var deployer;
async function main() {
     [deployer]=await ethers.getSigners();
     await addFacet("VaultFacet",true,true)

}
 async function addFacet(contractName,verify,isDeploy){
    var DiamondCutFacet=await ethers.getContractFactory("DiamondCutFacet")
    DiamondCutFacet = DiamondCutFacet.connect(deployer);
    DiamondCutFacet = DiamondCutFacet.attach(contractData.Diamond)
    var Contract;
    if(isDeploy){
      Contract= await  deployContract(contractName,verify)
    }else{
      Contract= await  getDeployedContract(contractName,contractData[contractName])
    }
    var args= await getSelectors(Contract)
    var tx=await DiamondCutFacet.diamondCut(args.diamondCut,args.init,args.calldata,{gasLimit:5000000})
    console.log(`<contract>:${Contract.address} add Selector  <hash>:${tx.hash}`)
    console.log("add diamond data done")
 }



async function getSelectors(contract){
    var signatures = Object.keys(contract.interface.functions)
    var selectors = signatures.reduce((acc, val) => { 
      if (val !== 'init(bytes)') {
        // console.log(`${contract.interface.getSighash(val)}-->${val}`)
        acc.push(contract.interface.getSighash(val))
      }
      return acc
    }, [])
    // let calldata = contract.interface.encodeFunctionData('setModules',[[contract.address],[true]])
    // console.log("calldata",calldata)
    // get already deployed contract selectorsList
    // var selectorList =await getSelectorList(contractData.LendFacet)
    let args={
        diamondCut:[{
            facetAddress:contract.address,
            addSelectors:selectors,
            removeSelectors:[]
            // addSelectors:[],
            // removeSelectors:selectorList
        }],
        init:ethers.constants.AddressZero,
        calldata:"0x"
    }
    return args
}
async function getSelectorList(address){
    var DiamondLoupeFacet = await getDeployedContract("DiamondLoupeFacet", contractData.Diamond)
   return await DiamondLoupeFacet.facetFunctionSelectors(address)
}

async function getDeployedContract(contractName, address, libraries){
   var contract = await ethers.getContractFactory(contractName, { libraries: libraries }, deployer);
    if (address) {
        contract = contract.attach(address);
    }
    return contract
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
