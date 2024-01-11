const { ethers } = require("hardhat");
const fs = require('fs');
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const tokenWhiteList =require("../jsonData137.json")

describe("Manager",function(){

    var deployer;
    var Manager;
    var sender;
    var VaultFacet;
    var PlatformFacet;
    before(async function(){

        [deployer]=await ethers.getSigners();


        Manager=await ethers.getContractFactory("Manager")
        Manager=Manager.connect(deployer)
        Manager=Manager.attach(contractData.Manager)

        VaultFacet=await ethers.getContractFactory("VaultFacet")
        VaultFacet=VaultFacet.connect(deployer)
        VaultFacet=VaultFacet.attach(contractData.Diamond)


        PlatformFacet=await ethers.getContractFactory("PlatformFacet")
        PlatformFacet=PlatformFacet.connect(deployer)
        PlatformFacet=PlatformFacet.attach(contractData.Diamond)
    })
    it.skip("setTokens",async function(){
       let _tokens=[]
       let _tokenTypes=[]
       for(let i=0;i<tokenWhiteList.length;i++){
        _tokens.push(tokenWhiteList[i].address)
        _tokenTypes.push(tokenWhiteList[i].type)
       } 
       var tx= await Manager.setTokens(_tokens,_tokenTypes)
       console.log("<tx>",tx)
       await tx.wait()
    })
    it.skip("getEth",async function(){
      let eth=   await  PlatformFacet.getEth()
      console.log("eth",eth)
    })
   
    it.skip("getVaultAllPosition",async function(){

      
       let result=await VaultFacet.getVaultAllPosition("0x171130275697ccc34526A20dC5cEfdCa38c729F6",[1]);
       console.log("result",result)
    //    var result2=await Manager.getVaultAllPosition("0x171130275697ccc34526A20dC5cEfdCa38c729F6",[1,2,3,4,5,6]);
    //    console.log("result2",result2)

    })
    it.only("setDBControlWhitelist",async function(){
       var tx= await Manager.setDBControlWhitelist([contractData.LeverageModule],[true])
       console.log(tx)
    })
    it.only("setModules",async function(){
       var tx=await Manager.setModules([contractData.LeverageModule],[true])
       console.log(tx)
    })
    it.skip("get facetAddresses",async function(){
       var result=await Manager.facetAddresses()
       console.log(result,"--")
    })
})