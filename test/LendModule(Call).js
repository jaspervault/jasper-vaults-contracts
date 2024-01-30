const { ethers } = require("hardhat");
const fs = require("fs");
const network = process.argv[process.argv.length - 1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
const { bundler } = require("./sendBundler.js");
let usdcToken = settings.tokens[0].address;
let wbtcToken = settings.tokens[1].address;
let wmatic = settings.tokens[4].address;
const domain = {
	name: settings.name,
	version: settings.version,
	chainId: settings.chainId,
	verifyingContract: contractData.LendModule
};

const types = {
	"CallOrder": [
		{ name: 'orderID', type: 'uint256' },
		{ name: 'optionHolder', type: 'address' },
		{ name: 'optionWriter', type: 'address' },
		{ name: 'recipientAddress', type: 'address' },
		{ name: 'underlyingAsset', type: 'address' },
		{ name: 'underlyingAmount', type: 'uint256' },
		{ name: 'receiveAsset', type: 'address' },
		{ name: 'borrowNowAmount', type: 'uint256' },
		{ name: 'borrowNowMinAmount', type: 'uint256' },
		{ name: 'optionPremiumAmount', type: 'uint256' },
		{ name: 'borrowLaterMinAmount', type: 'uint256' },
		{ name: 'borrowLaterAmount', type: 'uint256' },
		{ name: 'expirationDate', type: 'uint256' },
		{ name: 'platformFeeAmount', type: 'uint256' },
		{ name: 'index', type: 'uint256' },
		{ name: 'underlyingAssetType', type: 'uint256' },
		{ name: 'underlyingNftID', type: 'uint256' },
	]
};


let lenderSignature;
let borrowerSignature;
let transactionDate = parseInt(new Date().getTime() / 1000)
// let transactionDate = 1695874969
describe("LendingModule", function () {
	var deployer;
	var optionHolder;
	var optionWriter;
	var oneETH = "999999999999999"
	var oneUSdc = String(10 ** 5)
	var ERC20;
	var LendModule
	before(async function () {
		[deployer] = await ethers.getSigners();
		// console.log("deployer", deployer);

		LendModule = await ethers.getContractFactory("LendModule");
		LendModule = LendModule.connect(deployer);
		LendModule = LendModule.attach(contractData.LendModule);
		optionHolder = await bundler.getSender(4)
		optionWriter = await bundler.getSender(5)
		console.log("optionHolder", optionHolder)
		console.log("optionWriter", optionWriter)
	});
	it.only("optionHolder sign", async function () {
	
		// The data to sign
		const value = {
			orderID: 0,
			optionHolder: optionHolder,
			optionWriter: ethers.constants.AddressZero,
			recipientAddress: deployer.address,
			underlyingAsset: usdcToken,//wmatic,
			underlyingAmount: oneUSdc,
			receiveAsset: wmatic, //usdc
			borrowNowAmount: 0,
			borrowNowMinAmount: String(10 ** 16),
			optionPremiumAmount: String(10 ** 15),
			borrowLaterMinAmount: String(10 ** 16),
			borrowLaterAmount: 0,
			expirationDate: transactionDate + 160,
			platformFeeAmount: String(10 ** 10),
			index: 0,
			underlyingAssetType: 0,
			underlyingNftID: 0
		};
		borrowerSignature = await deployer._signTypedData(domain, types, value);
		console.log("<optionHolder sign data>", borrowerSignature, value)
		const recoveredAddress = ethers.utils.verifyTypedData(domain, types, value, borrowerSignature);
		console.log("recoveredAddress", recoveredAddress)

	})

	it.only("optionWriter sign", async function () {

	// The data to sign 
		const value = {
			orderID: 0,
			optionHolder: optionHolder,
			optionWriter: optionWriter,
			recipientAddress: deployer.address,
			underlyingAsset: usdcToken,//wmatic,
			underlyingAmount: oneUSdc,
			receiveAsset: wmatic, //usdc
			borrowNowAmount: String(10 ** 16),
			borrowNowMinAmount: String(10 ** 16),
			optionPremiumAmount: String(10 ** 15),
			borrowLaterMinAmount: String(10 ** 16),
			borrowLaterAmount: String(10 ** 16),
			expirationDate: transactionDate + 160,
			platformFeeAmount: String(10 ** 10),
			index: 0,
			underlyingAssetType: 0,
			underlyingNftID: 0
		};
		lenderSignature = await deployer._signTypedData(domain, types, value);
		console.log("<optionWriter sign data>", lenderSignature, value)
		const recoveredAddress = ethers.utils.verifyTypedData(domain, types, value, lenderSignature);
		console.log("optionWriter recoveredAddress", recoveredAddress)

	})
	it.skip("submitOrder", async function () {
		console.log("deployer.address", deployer.address)
		console.log("optionHolder.address", optionHolder)
		console.log("optionWriter.address", optionWriter)
		const value = {
			orderID: 0,
			optionHolder: optionHolder,
			optionWriter: optionWriter,
			recipientAddress: deployer.address,
			underlyingAsset: usdcToken,//wmatic,
			underlyingAmount: oneUSdc,
			receiveAsset: wmatic, //usdc
			borrowNowAmount: String(10 ** 16),
			borrowNowMinAmount: String(10 ** 16),
			optionPremiumAmount: String(10 ** 15),
			borrowLaterMinAmount: String(10 ** 16),
			borrowLaterAmount: String(10 ** 16),
			expirationDate: transactionDate + 160,
			platformFeeAmount: String(10 ** 10),
			index: 0,
			underlyingAssetType: 0,
			underlyingNftID: 0
		};
		let calldata = LendModule.interface.encodeFunctionData("submitCallOrder", [
			value,
			borrowerSignature,
			lenderSignature,
		]);

		console.log([contractData.LendModule], [0], [calldata])
		await bundler.setSender(4)
		await bundler.sendBundler([contractData.LendModule], [0], [calldata]);
	});
	it.only("liquidateOrder", async function () {
		optionHolder = await bundler.setSender(4);
		let token = settings.tokens[0].address

		// let abi = [{
		// 	"constant": false,
		// 	"inputs": [
		// 		{
		// 			"name": "_spender",
		// 			"type": "address"
		// 		},
		// 		{
		// 			"name": "_value",
		// 			"type": "uint256"
		// 		}
		// 	],
		// 	"name": "approve",
		// 	"outputs": [],
		// 	"payable": false,
		// 	"stateMutability": "nonpayable",
		// 	"type": "function"
		// }]
		// ERC20 = await new ethers.Contract(token, abi, ethers.provider).connect(deployer)
		// var tx = await ERC20.approve(contractData.LendModule, 10 ** 6)
		// console.log("<approve>", tx.hash)
		var tx = await LendModule.liquidateCallOrder(optionWriter, true)
		console.log("<tx>", tx.hash)
	});


	async function getDeployedContract(contractName, address, libraries) {
		var contract = await ethers.getContractFactory(contractName, { libraries: libraries }, deployer);
		if (address) {
			contract = contract.attach(address);
		}
		return contract
	}

	it.skip("optionWriter unlock", async function () {

		var VaultFacet = await getDeployedContract("VaultFacet", contractData.Diamond)
		let tx = await VaultFacet.getVaultType(optionWriter)
		// let tx = await VaultFacet.setVaultLock(optionWriter, false)
		console.log("setVaultLock hash", tx.hash)
	},)

});

