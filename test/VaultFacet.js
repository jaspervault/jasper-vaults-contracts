const { ethers } = require("hardhat");
const fs = require('fs');
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));

let vault="0x49f52d492217F14573C1cc3Ee9F975F57886252C"
describe("Diamond",function(){
  var deployer;
  var Diamond;
  var VaultFacet;
  var LendModule;
  before(async function(){
    [deployer]=await ethers.getSigners();
    Diamond=await ethers.getContractFactory("Diamond")
    Diamond = Diamond.connect(deployer);
    Diamond = Diamond.attach(contractData.Diamond)


    VaultFacet=await ethers.getContractFactory("VaultFacet")
    VaultFacet = VaultFacet.connect(deployer);
    VaultFacet = VaultFacet.attach(contractData.Diamond)


    LendModule=await ethers.getContractFactory("LendModule")
    LendModule = LendModule.connect(deployer);
    LendModule = LendModule.attach(contractData.LendModule)
   
    let result= await getSelectors(LendModule) 
   console.log(result,"---")
  })

  it.skip("get modules",async function(){
     let modules= await VaultFacet.getVaultAllModules(vault)
     console.log("<modules>",modules)
  })
  it.skip("get tokens",async function(){
    let tokens= await VaultFacet.getVaultAllTokens(vault)
    console.log("<tokens>",tokens)
 }) 

 it.skip("get protocols",async function(){
    let protocols= await VaultFacet.getVaultAllProtocol(vault)
    console.log("<protocols>",protocols)
 })
})
async function getSelectors(contract){
   var signatures = Object.keys(contract.interface.functions)
   var selectors = signatures.reduce((acc, val) => { 
     if (val !== 'init(bytes)') {
       console.log(`${contract.interface.getSighash(val)}-->${val}`)
       acc.push(contract.interface.getSighash(val))
     }
     return acc
   }, [])
   console.log("selectors",selectors)
   // let calldata = contract.interface.encodeFunctionData('setModules',[[contract.address],[true]])
   // console.log("calldata",calldata)
   let args={
       diamondCut:[{
           facetAddress:contract.address,
           addSelectors:selectors,
           removeSelectors:[]
       }],
       init:ethers.constants.AddressZero,
       calldata:"0x"
   }
   return args
}

