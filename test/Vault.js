const { ethers } = require("hardhat");
const fs = require('fs');




let vault="0x0D513690a2314c43C61de4b46CCcb7b5808BF1a2"
describe("Vault",function(){
  var deployer;
  var Vault;
  before(async function(){
    [deployer]=await ethers.getSigners();
    Vault=await ethers.getContractFactory("Vault")
    Vault = Vault.connect(deployer);
    Vault = Vault.attach(vault)
  })
  it.only("estimateGas",async function(){
    let sqrtPriceX96="1671326640268361191493509194738206"
    const sqrtPriceX96BigNumber =  ethers.BigNumber.from(sqrtPriceX96);
    let value=ethers.BigNumber.from(2).pow(192)
    var price=sqrtPriceX96BigNumber.pow(2).div(value)  //token/toke1 的价格  usdc/weth
    // const priceX192 = sqrtPriceX96BigNumber.mul(sqrtPriceX96BigNumber);
    console.log( 10**12/price);

    
   

    // sqrtPriceX96 = sqrt(price) * 2 ** 96
    // # divide both sides by 2 ** 96
    // sqrtPriceX96 / (2 ** 96) = sqrt(price)
    // # square both sides
    // (sqrtPriceX96 / (2 ** 96)) ** 2 = price
    // # expand the squared fraction
    // (sqrtPriceX96 ** 2) / ((2 ** 96) ** 2)  = price
    // # multiply the exponents in the denominator to get the final expression
    // sqrtRatioX96 ** 2 / 2 ** 192 = price
  
  })
  it.skip("upgradeTo",async function(){
    // let data="0xbfa9acef000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000a58222693c3e463e54d095ee1e6119e85c25e9c300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
    // var tx= await  Vault.upgradeToAndCall("0xffec1c79f6df206d5534594940ca0be2dfbae99f",data,{value:0,gasLimit:3000000})
    // console.log(tx)
    // await tx.wait(1)
    let imp="0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    var tx=await Vault.upgradeTo(imp)
    console.log(tx)
    await tx.wait();
  })

})
