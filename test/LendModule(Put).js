const { ethers } = require("hardhat");
const fs = require("fs");
const network = process.argv[process.argv.length - 1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
const { bundler } = require("./sendBundler.js");
let usdcToken = settings.tokens[0].address;
let wbtcToken = settings.tokens[1].address;
const domain = {
	name: settings.name,
	version: settings.version,
	chainId: settings.chainId,
	verifyingContract: contractData.LendModule
};

const types = {
	"PutOrder": [
		{ name: 'orderID', type: 'uint256' },
		{ name: 'optionWriter', type: 'address' },
		{ name: 'optionHolder', type: 'address' },
		{ name: 'recipientAddress', type: 'address' },
		{ name: 'underlyingAsset', type: 'address' },
		{ name: 'underlyingAmount', type: 'uint256' },
		{ name: 'receiveAsset', type: 'address' },
		{ name: 'receiveMinAmount', type: 'uint256' },
		{ name: 'receiveAmount', type: 'uint256' },
		{ name: 'expirationDate', type: 'uint256' },
		{ name: 'platformFeeAmount', type: 'uint256' },
		{ name: 'index', type: 'uint256' },
		{ name: 'optionPremiumAmount', type: 'uint256' },
		{ name: "underlyingAssetType", type: "uint256" },
		{ name: "underlyingNftID", type: "uint256" }
	]
};
let lenderSignature;
let borrowerSignature;
let transactionDate = parseInt(new Date().getTime() / 1000)
// let transactionDate = 1695874969 
describe("LendingModule", function () {
	var deployer;
	var debtor;
	var loaner;

	var ERC20;
	before(async function () {
		[deployer] = await ethers.getSigners();
		// console.log("deployer", deployer);
		LendModule = await ethers.getContractFactory("LendModule");
		LendModule = LendModule.connect(deployer);
		LendModule = LendModule.attach(contractData.LendModule);
		debtor = await bundler.getSender(2)
		loaner = await bundler.getSender(3)
		console.log("debtor", debtor)
		console.log("loaner", loaner)

	});
	it.only("debtor sign", async function () {

		/**
		 *
		 *  { name: 'from', type: 'address' },
			{ name: 'to', type: 'address' },
			{ name: 'contents', type: 'string' },
			{ name: 'data', type: 'bytes' },
			{ name: 'data2', type: 'uint256[]' },
			{ name: 'data3', type: 'string[]' },
			0x2f9f8069f7e3be51286e5ebaf35d84a585c1c5b1135c557f44d4606772bf6f75
			0x2f9f8069f7e3be51286e5ebaf35d84a585c1c5b1135c557f44d4606772bf6f75

		 */

		// The data to sign
		const value = {
			orderID: 0,
			optionWriter: ethers.constants.AddressZero,
			optionHolder: debtor,
			recipientAddress: deployer.address,
			underlyingAsset: settings.tokens[5].address,//wmatic
			underlyingAmount: "430923722",
			receiveAsset: settings.tokens[0].address,
			receiveMinAmount: 10 ** 6,
			receiveAmount: 0,
			expirationDate: transactionDate + 3600,
			platformFeeAmount: `${10 ** 4}`,
			index: 0,
			optionPremiumAmount: 0,
			underlyingAssetType: 1,
			underlyingNftID: 1122294
		};
		borrowerSignature = await deployer._signTypedData(domain, types, value);
		console.log("<debtor sign data>", borrowerSignature, value)
		const recoveredAddress = ethers.utils.verifyTypedData(domain, types, value, borrowerSignature);
		console.log("recoveredAddress", recoveredAddress)

	})
	it.only("loaner sign", async function () {
	
		// The data to sign
		const value = {
			orderID: 0,
			optionWriter: loaner,
			optionHolder: debtor,
			recipientAddress: deployer.address,
			underlyingAsset: settings.tokens[5].address,//wmatic
			underlyingAmount: "430923722",
			receiveAsset: settings.tokens[0].address,
			receiveMinAmount: 10 ** 6,
			receiveAmount: 10 ** 6,
			expirationDate: transactionDate + 3600,
			platformFeeAmount: `${10 ** 4}`,
			index: 0,
			optionPremiumAmount: 0,
			underlyingAssetType: 1,
			underlyingNftID: 1122294
		};
		lenderSignature = await deployer._signTypedData(domain, types, value);
		console.log("<loaner sign data>", lenderSignature, value)

	})

	it.skip("submitOrder", async function () {
		console.log("deployer.address", deployer.address)
		console.log("loaner.address", debtor)
		console.log("debtor.address", loaner)
		var putOrder = {
			orderID: 0,
			optionWriter: loaner,
			optionHolder: debtor,
			recipientAddress: deployer.address,
			underlyingAsset: settings.tokens[5].address,
			underlyingAmount: "430923722",
			receiveAsset: settings.tokens[0].address,
			receiveMinAmount: 10 ** 6,
			receiveAmount: 10 ** 6,
			expirationDate: transactionDate + 3600,
			platformFeeAmount: `${10 ** 4}`,
			index: 0,
			optionPremiumAmount: 0,
			underlyingAssetType: 1,
			underlyingNftID: 1122294
		}
		let calldata = LendModule.interface.encodeFunctionData("submitPutOrder", [
			putOrder,
			borrowerSignature,
			lenderSignature
		]);
		console.log(putOrder, "--")
		await bundler.setSender(4)
		await bundler.sendBundler([contractData.LendModule], [0], [calldata]);
	});
	it.only("liquidateOrder", async function () {
		// debtor = await bundler.setSender(4);
		// token=settings.tokens[0].address

		// let abi=[{
		//     "constant": false,
		//     "inputs": [
		//         {
		//             "name": "_spender",
		//             "type": "address"
		//         },
		//         {
		//             "name": "_value",
		//             "type": "uint256"
		//         }
		//     ],
		//     "name": "approve",
		//     "outputs": [],
		//     "payable": false,
		//     "stateMutability": "nonpayable",
		//     "type": "function"
		// }]
		// ERC20=await new ethers.Contract(token,abi,ethers.provider).connect(deployer)
		// var tx=await  ERC20.approve(contractData.LendModule, 5000000)
		// console.log("<approve>",tx.hash)
		let debtor = await bundler.getSender(2)
		var tx = await LendModule.liquidatePutOrder(debtor, true, { gasLimit: 2000000 })
		console.log("<tx>", tx.hash)
	});

});
