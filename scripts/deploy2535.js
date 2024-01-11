const { ethers,upgrades,run } = require('hardhat');
const network = process.env.HARDHAT_NETWORK
const fs = require('fs');
var contractData={}
var deployer;
async function main() {
    [deployer]=await ethers.getSigners();
    //部署2535合约
    var DiamondCutFacet=await deployContract("DiamondCutFacet",false)

    var DiamondLoupeFacet=await deployContract("DiamondLoupeFacet",false)


    var OwnershipFacet=await deployContract("OwnershipFacet",false)
    var diamondFacets=[]
    // var diamondArgs={
    //     owner:deployer.address,
    //     init:ethers.constants.AddressZero, 
    //     initCalldata:'0x'
    // }
    let calldata = OwnershipFacet.interface.encodeFunctionData('setModules',[[OwnershipFacet.address],[true]])
    var diamondArgs={
        owner:deployer.address,
        init:OwnershipFacet.address, 
        initCalldata:calldata
    }


    var diamondCutSelectors=getSelectors(DiamondCutFacet)
    diamondFacets.push({
        facetAddress:DiamondCutFacet.address,
        addSelectors:diamondCutSelectors,
        removeSelectors:[]
    })
    var diamondLoupeSelectors=getSelectors(DiamondLoupeFacet)
    diamondFacets.push({
        facetAddress:DiamondLoupeFacet.address,
        addSelectors:diamondLoupeSelectors,
        removeSelectors:[]
    })
    var ownershipSelectors=getSelectors(OwnershipFacet)
    diamondFacets.push({
        facetAddress:OwnershipFacet.address,
        addSelectors:ownershipSelectors,
        removeSelectors:[]
    })

   var Diamond=await deployContract("Diamond",false,diamondFacets,diamondArgs)

   //部署相关数据合约
   var PlatformFacet= await  deployContract("PlatformFacet",false) 
   await addFunction(PlatformFacet)

   fs.writeFileSync(`contractData.2535.json`, JSON.stringify(contractData));
}
async function addFunction(contract){
   
    var DiamondCutFacet=await ethers.getContractFactory("DiamondCutFacet")
    DiamondCutFacet = DiamondCutFacet.connect(deployer);
    DiamondCutFacet = DiamondCutFacet.attach(contractData.Diamond)
    var selectors=getSelectors(contract) 
    var _diamondCut=[{
        facetAddress:contract.address,
        addSelectors:selectors,
        removeSelectors:[]
    }]
    // 要做的事情
    // let calldata = contract.interface.encodeFunctionData('setModules',[[contract.address],[true]])
    // console.log("calldata",calldata)
    // await DiamondCutFacet.diamondCut(_diamondCut,contract.address,calldata)
    await DiamondCutFacet.diamondCut(_diamondCut,ethers.constants.AddressZero,"0x")


}

function getSelectors(contract){
    var signatures = Object.keys(contract.interface.functions)
    var selectors = signatures.reduce((acc, val) => { 
      if (val !== 'init(bytes)') {
        console.log(`${contract.interface.getSighash(val)}-->${val}`)
        acc.push(contract.interface.getSighash(val))
      }
      return acc
    }, [])
    console.log(`${contract.address}<selectors>`,selectors)
    return selectors
}


async function deployContract(contractName, verify, ...args){
  const Contract = await ethers.getContractFactory(contractName);
  var contract = await Contract.deploy(...args);
  console.log("<" + contractName + "> contract address: ", contract.address + " hash: " + contract.deployTransaction.hash);
  contractData[contractName]=contract.address;
  await contract.deployed()
//   if (verify) {
//       var r = await contract.deployTransaction.wait(5);
//       try {
//           await run("verify:verify", {
//               address: contract.address,
//               constructorArguments: args,
//           });
//           console.log("verified contract <" + contractName + "> address:", contract.address);
//       } catch (error) {
//           console.log(error.message);
//           return contract;
//       }
//   }
//   else {
//       var r = await contract.deployTransaction.wait(1);
//   }
  return contract;
}

// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });


exports.deployDiamond = main