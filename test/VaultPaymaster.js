const { ethers } = require("hardhat");
const fs = require('fs');
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
let token="0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
describe("VaultPaymaster",function(){
  var deployer;
  var VaultPaymaster;
  before(async function(){
    [deployer]=await ethers.getSigners();
    VaultPaymaster=await ethers.getContractFactory("VaultPaymaster")
    VaultPaymaster = VaultPaymaster.connect(deployer);
    VaultPaymaster = VaultPaymaster.attach(contractData.VaultPaymaster)
  })
  it.skip("approve",async function(){
    let abi=[{
        "constant": false,
        "inputs": [
            {
                "name": "_spender",
                "type": "address"
            },
            {
                "name": "_value",
                "type": "uint256"
            }
        ],
        "name": "approve",
        "outputs": [],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
    }]
    ERC20=await new ethers.Contract(token,abi,ethers.provider).connect(deployer)
    var tx=  await  ERC20.approve(VaultPaymasterAddr,`${1*10**6}`)
    console.log("<approve>",tx.hash)
})
  it.skip("deposit",async function(){
    let   depositInfo={
       wallet:"0x561300dd88A3F734a3217192bBDd9331f7685356",
       protocol:"UniswapV2ExchangeAdapter",
       positionType:1,
       sendAsset:token, 
       receiveAsset:"0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
       adapterType:0,  
       amountIn:1000000,
       amountLimit:100000,
       approveAmount:1000000,
       adapterData:"0x"
   }
    let adapterData= ethers.utils.defaultAbiCoder.encode(["address[]"],[[token,"0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"]])
    depositInfo.adapterData=adapterData
    let tx= await VaultPaymaster.deposit(depositInfo)
    console.log("deposit",tx)
  })
  it.skip("setCostOfPost",async function(){
    var tx=await VaultPaymaster.setCostOfPost(30000)
    console.log(tx,"tx")
  })

})

