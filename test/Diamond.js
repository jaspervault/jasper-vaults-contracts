const { ethers } = require("hardhat");
const fs = require('fs');
// const { deployDiamond } = require('../scripts/deploy2535.js')
const network = process.argv[process.argv.length - 1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const data = require("../jsonData137.json")
describe("Diamond", function () {
  var deployer;
  var Diamond;
  let DiamondCutFacet
  let DiamondLoupeFacet
  let OwnershipFacet
  let PlatformFacet;
  var VaultFacet
  var LendFacet
  var LeverageFacet
  before(async function () {
    [deployer] = await ethers.getSigners();

    // await deployDiamond()
    console.log("contractData", contractData)
    Diamond = await ethers.getContractFactory("Diamond")
    Diamond = Diamond.connect(deployer);
    Diamond = Diamond.attach(contractData.Diamond)


    DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet")
    DiamondCutFacet = DiamondCutFacet.connect(deployer);
    DiamondCutFacet = DiamondCutFacet.attach(contractData.Diamond)

    DiamondLoupeFacet = await ethers.getContractFactory("DiamondLoupeFacet")
    DiamondLoupeFacet = DiamondLoupeFacet.connect(deployer);
    DiamondLoupeFacet = DiamondLoupeFacet.attach(contractData.Diamond)

    OwnershipFacet = await ethers.getContractFactory("OwnershipFacet")
    OwnershipFacet = OwnershipFacet.connect(deployer);
    OwnershipFacet = OwnershipFacet.attach(contractData.Diamond)

    PlatformFacet = await ethers.getContractFactory("PlatformFacet")
    PlatformFacet = PlatformFacet.connect(deployer);
    PlatformFacet = PlatformFacet.attach(contractData.Diamond)

    VaultFacet = await ethers.getContractFactory("VaultFacet")
    VaultFacet = VaultFacet.connect(deployer);
    VaultFacet = VaultFacet.attach(contractData.Diamond)

    LendFacet = await ethers.getContractFactory("LendFacet")
    LendFacet = LendFacet.connect(deployer);
    LendFacet = LendFacet.attach(contractData.Diamond)
 
    LeverageFacet = await ethers.getContractFactory("LeverageFacet")
    LeverageFacet = LeverageFacet.connect(deployer);
    LeverageFacet = LeverageFacet.attach(contractData.Diamond)   

  })
  
  it.skip("get owner", async function () {
    var result = await OwnershipFacet.owner()
    console.log("owner", result, deployer.address)
  })

  it.skip("get all facets", async function () {
    var result = await DiamondLoupeFacet.facets()
    console.log("facets", result)
  })

  it.skip("add module", async function () {
    let modules = [
      "0xBe4424f51054f4B9C9980D0F462f4B3284D708F1",
      "0xd0DC4E0eE24146DBEeF13479e4C658cAA0c6CA95",
      "0x5935f4310448e9C0c1e548d0485bF2A4931C3e09",
      "0x229BCdC186147a5FD09C84A8803027558be6ea52",
      "0xC6f9EE8453a91848D7b24B92654Dc1252a0e430A",
      "0x3136bD20782E134bFaE2d37DE8D378Ae09726139"
    ]
    let status = [true, true, true, true, true, true]

    var tx = await PlatformFacet.setModules(modules, status)
    console.log("add module", tx)
    await tx.wait(1);
  })

  it.skip("get PlatformFacet module", async function () {
    var result = await PlatformFacet.getAllModules()
    console.log("PlatformFacet module", result)


  })

  it.skip("add protocol", async function () {
    await PlatformFacet.setProtocols(["uniswapV3"], [true])
  })
  it.skip("get all protocol", async function () {
    var result = await PlatformFacet.getProtocols()
    console.log("all protocol", result)
  })
  it.skip("get getVaultImplementation", async function () {
    var result = await PlatformFacet.getVaultImplementation()
    console.log("all getVaultImplementation", result)
  })
  it.skip("setDBControlWhitelist", async function () {
    var result = await OwnershipFacet.setDBControlWhitelist([contractData.UniswapV2ExchangeAdapter, contractData.UniswapV3ExchangeAdapter,], [true, true])
  })
  it.skip("setTokens", async function () {
    let tokens = []
    let tokenTypes = []
    for (let i = 0; i < data.length; i++) {
      tokens.push(data[i].address);
      tokenTypes.push(data[i].type)
    }
    console.log(tokens, tokenTypes)
    var result = await PlatformFacet.setTokens(tokens, tokenTypes)
    console.log("setTokens", result)
  })


  it.skip("setWeth", async function () {
    var result = await PlatformFacet.setWeth("0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6")
    console.log("setWeth", result)
    await result.wait(1);
  })
  it.skip("getVaultProtocolPosition", async function () {
    var result = await VaultFacet.getVaultProtocolPosition("0x665f8d9a3f1b6e9081cf60cf2622fab984a61097", 6)
    console.log("setWeth", result)
  })
   
  it.skip("LendFacet setLendFeePlatformRecipient",async function(){
     let tx=  await LendFacet.setLendFeePlatformRecipient("0x758dc51d6A6A9BcaE8bdB91587790b9b2239db30")
     console.log(tx,"LendFacet")
  })
  
  it.skip("LeverageFacet setLendFeePlatformRecipient",async function(){
    //0x758dc51d6A6A9BcaE8bdB91587790b9b2239db30
     let tx=await LeverageFacet.setleverageLendPlatformFeeRecipient("0x758dc51d6A6A9BcaE8bdB91587790b9b2239db30")
     console.log(tx,"LeverageFacet")
  })
  it.skip("PlatformFacet assetTypeCount",async function(){
     let tx=await PlatformFacet.setAssetTypeCount(6)
    await tx.wait(1)
     console.log(tx)
  })
  it.only("IVaultFacet getVaultAllPosition",async function(){
    let tx=await VaultFacet.getVaultAllPosition("0x6bdEf429C9465e632CF35b91Cc270590A2d40599",[1])
    console.log(tx)
 })
})


