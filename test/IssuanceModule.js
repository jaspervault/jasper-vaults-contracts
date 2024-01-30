const { ethers } = require("hardhat");
const fs = require('fs');
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));  
const { bundler } = require('./sendBundler.js')
let token=settings.tokens[0].address
// let token="0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
var sender
var index=30
describe("IssuanceModule",function(){
    var deployer;
    var IssuanceModule;
    var ERC20;
    var decimals
    before(async function(){
        [deployer]=await ethers.getSigners();
        sender = await bundler.setSender(index)
        IssuanceModule=await ethers.getContractFactory("IssuanceModule")
        IssuanceModule=IssuanceModule.connect(deployer)
        IssuanceModule=IssuanceModule.attach(contractData.IssuanceModule)
        console.log(sender,token)
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
    
        var tx=  await  ERC20.approve(sender,`${1*10**4}`)     
        console.log("<approve>",tx.hash)
    })


    it.skip("issue",async function(){
        let target=IssuanceModule.address
        let tokens=[token]
        let amount=`${1*10**4}`
       let calldata= IssuanceModule.interface.encodeFunctionData("issue(address _vault, address _from, address[] memory _assets,uint256[] memory _amounts) ",
        [sender,deployer.address,tokens,[amount]]
       ) 
       await bundler.sendBundler([target],[0],[calldata])
    })
    
    it.only("redeem",async function(){
        let target=IssuanceModule.address
        let value=[0]
        let token2=[token]
        let calldata= IssuanceModule.interface.encodeFunctionData("redeem",[sender,deployer.address,[1],token2,[0]])
        await bundler.sendBundler([target],value,[calldata])  
    })
    
})

