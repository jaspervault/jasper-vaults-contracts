const {ethers} = require("hardhat");
const fs = require('fs');
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
const {bundler} = require('./sendBundler.js')
// const data2 =require("./01.json")
describe("CreateVault", function () {
	var deployer;
	var sender;
	var VaultFactory;
	var VaultManageModule;
	var IssuanceModule;
	var TradeModule;
	var index =30
	var SenderCreator;
	before(async function () {
		[deployer] = await ethers.getSigners();
		VaultFactory = await ethers.getContractFactory("VaultFactory")
		VaultFactory = VaultFactory.connect(deployer);
		VaultFactory = VaultFactory.attach(contractData.VaultFactory)

		VaultManageModule = await ethers.getContractFactory("VaultManageModule")
		VaultManageModule = VaultManageModule.connect(deployer)
		VaultManageModule = VaultManageModule.attach(contractData.VaultManageModule)

		IssuanceModule = await ethers.getContractFactory("IssuanceModule")
		IssuanceModule = IssuanceModule.connect(deployer)
		IssuanceModule = IssuanceModule.attach(contractData.IssuanceModule)

		TradeModule = await ethers.getContractFactory("TradeModule")
		TradeModule = TradeModule.connect(deployer)
		TradeModule = TradeModule.attach(contractData.TradeModule)
		// sender = await bundler.setSender(2)
	})
	it.only("initVault", async function () {
		let dest = []
		let func = []
		let value = []
		console.log("----")

	
		//----------
		sender = await bundler.setSender(index)
		let modules = [contractData.VaultPaymaster, contractData.VaultManageModule, contractData.TradeModule, contractData.IssuanceModule, contractData.LendModule]
		let modulesStatus = [true, true, true, true, true]
		let callData3 = VaultManageModule.interface.encodeFunctionData("setVaultModule", [sender, modules, modulesStatus])
		dest.push(VaultManageModule.address)
		value.push(0)
		func.push(callData3)
		let callData31 = VaultManageModule.interface.encodeFunctionData("setVaultType", [sender, 6])
		dest.push(VaultManageModule.address)
		value.push(0)
		func.push(callData31)
		//------------
		var calldata = VaultManageModule.interface.encodeFunctionData("setVaultMasterToken", [sender, settings.tokens[0].address])
		dest.push(VaultManageModule.address)
		value.push(0)
		func.push(calldata)
		//------------
		let protocols = [contractData.UniswapV2ExchangeAdapter, contractData.UniswapV3ExchangeAdapter]
		let protocolsStatus = [true, true]
		let callData2 = VaultManageModule.interface.encodeFunctionData("setVaultProtocol", [sender, protocols, protocolsStatus])
		dest.push(VaultManageModule.address)
		value.push(0)
		func.push(callData2)

		//-------------
		let tokens = []
		let types = []
		for (let i = 0; i < settings.tokens.length; i++) {
			tokens.push(settings.tokens[i].address)
			types.push(String(settings.tokens[i].type))
		}
		let callData4 = VaultManageModule.interface.encodeFunctionData("setVaultTokens", [sender, tokens, types])
		dest.push(VaultManageModule.address)
		value.push(0)
		func.push(callData4)

		// let assets="0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
		// let calldata5= IssuanceModule.interface.encodeFunctionData("issue",[sender,deployer.address,[assets],[1],[3000000]])
		// dest.push(IssuanceModule.address)
		// value.push(0)
		// func.push(calldata5)

		//    let path=["0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174","0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"]
		//    let adapterData=ethers.utils.defaultAbiCoder.encode(["address[]"],[path]);

	
		//    let path2=`0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174${(Number(3000)).toString(16).padStart(6,"0")}0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270`
		//    let sqrtPriceLimitX96=0
		//    let isEth=false
		//    let adapterData2=ethers.utils.defaultAbiCoder.encode(["bytes","uint160","bool"],[path2,sqrtPriceLimitX96,isEth]);
		//    let tradeInfo=[{
		//        protocol:"UniswapV2ExchangeAdapter",
		//        positionType:"1",
		//        sendAsset:"0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", 
		//        receiveAsset:"0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
		//        adapterType:0,
		//        amountIn:1000000,
		//        amountLimit:100000000,
		//        approveAmount:1000000,
		//        adapterData:adapterData  
		//       },
		//       {
		//         protocol:"UniswapV3ExchangeAdapter", 
		//         positionType:"1",
		//         sendAsset:"0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", 
		//         receiveAsset:"0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
		//         adapterType:0,
		//         amountIn:1000000,
		//         amountLimit:100000000,
		//         approveAmount:1000000,
		//         adapterData:adapterData2 
		//     }
		//    ]

		//    let calldata6= TradeModule.interface.encodeFunctionData("trade",[sender,tradeInfo])
		//    dest.push(TradeModule.address)
		//    value.push(0)
		//    func.push(calldata6)
		
		//    let assetsList=["0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174","0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"]
		//    let calldata7= IssuanceModule.interface.encodeFunctionData("redeem",[sender,deployer.address,assetsList,[1,1],[0,0]])
		//    dest.push(IssuanceModule.address)
		//    value.push(0)
		//    func.push(calldata7)
	
		await bundler.sendBundler(dest, value, func)
	})
	it.skip("setVaultType", async function () {
		let dest = []
		let func = []
		let value = []
        sender = await  bundler.setSender(index)
		let callData = VaultManageModule.interface.encodeFunctionData("setVaultType", [sender, 2])
		dest.push(VaultManageModule.address)
		value.push(0)
		func.push(callData)
		await bundler.sendBundler(dest, value, func)
		ethers.constants.AddressZero
		// console.log(bundler, "bundler")
	})

	it.skip("get code", async function () {
		let provider = ethers.provider
		let code = await provider.getCode(sender)
		console.log(code, "----")
	})


	it.skip("getWallet", async function () {
		var result = await VaultFactory.getWalletToVault(deployer.address);
		console.log("<result>", result)
	})
	it.skip("add setVaultTokens", async function () {
		let dest = []
		let func = []
		let value = []
		let tokens = ["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"]
		let types = [1]
		let callData4 = VaultManageModule.interface.encodeFunctionData("setVaultTokens", [sender, tokens, types])
		dest.push(VaultManageModule.address)
		value.push(0)
		func.push(callData4)
		await bundler.sendBundler(dest, value, func)
	})


})

