const { ethers } = require("hardhat");
const fs = require('fs');
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));  
const { bundler } = require('./sendBundler.js')
let token=settings.tokens[0].address
// let token="0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
var sender
var index=5
describe("IssuanceModule",function(){
    var deployer;
    var IssuanceModule;
    var ERC20;
    var decimals
    before(async function(){
        [deployer]=await ethers.getSigners();
        console.log(deployer.address,"+++")
        sender = await bundler.setSender(index)
        IssuanceModule=await ethers.getContractFactory("IssuanceModule")
        IssuanceModule=IssuanceModule.connect(deployer)
        IssuanceModule=IssuanceModule.attach(contractData.IssuanceModule)
        console.log(sender,token)
    })
    it.only("approve",async function(){
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
        var tx=  await  ERC20.approve(sender,`${1*10**5}`)
        // var tx=  await  ERC20.approve(sender,`1105354`)
        
        console.log("<approve>",tx.hash)
    })

    it.only("issue",async function(){
       let target=IssuanceModule.address
       let tokens=[token]
       let amount=`${1*10**5}`
    //    let amount=`1105354`
       // sender= await bundler.setSender(2)
       let calldata= IssuanceModule.interface.encodeFunctionData("issue(address _vault, address _from, address[] memory _assets,uint256[] memory _amounts) ",
           [sender,deployer.address,tokens,[amount]]
       )

       await bundler.sendBundler([target],[0],[calldata])
    })

    it.skip("issueFromOwner",async function(){
       let vault="0x0b9cfb07Eb94C5CaC2fAD4043648ffa26c967b46"
       let tx= await IssuanceModule.issueFromOwner(vault,["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"],[`${1*10**17}`],{value:`${10**17}`,gasLimit:3000000}); 
       console.log("tx",tx)    
    })

    it.skip("redeem",async function(){
        let target=IssuanceModule.address
        let value=[0]
        let token2=[token]
        // let calldata= IssuanceModule.interface.encodeFunctionData("redeem",[sender,"0x665f8D9a3f1B6e9081Cf60cf2622FaB984A61097",[2],token,[83409]])
        let calldata= IssuanceModule.interface.encodeFunctionData("redeem",[sender,deployer.address,[1],token2,[0]])
        await bundler.sendBundler([target],value,[calldata])
    })

    
})

