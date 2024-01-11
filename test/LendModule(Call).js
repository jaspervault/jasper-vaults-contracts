const {ethers} = require("hardhat");
const fs = require("fs");
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
const {bundler} = require("./sendBundler.js");
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
		{name: 'orderId', type: 'uint256'},
		{name: 'borrower', type: 'address'},
		{name: 'lender', type: 'address'},
		{name: 'recipient', type: 'address'},
		{name: 'collateralAsset', type: 'address'},
		{name: 'collateralAmount', type: 'uint256'},
		{name: 'borrowAsset', type: 'address'},
		{name: 'borrowNowAmount', type: 'uint256'},
		{name: 'borrowNowMinAmount', type: 'uint256'},
		{name: 'interestAmount', type: 'uint256'},
		{name: 'borrowLaterMinAmount', type: 'uint256'},
		{name: 'borrowLaterAmount', type: 'uint256'},
		{name: 'expirationDate', type: 'uint256'},
		{name: 'platformFee', type: 'uint256'},
		{name: 'index', type: 'uint256'},
		{name: 'collateralAssetType', type: 'uint256'},
		{name: 'collateralNftId', type: 'uint256'},
	]
};


let lenderSignature;
let borrowerSignature;
let transactionDate=parseInt(new Date().getTime()/1000)
// let transactionDate = 1695874969
describe("LendingModule", function () {
	var deployer;
	var borrower;
	var lender;
	var oneETH ="999999999999999" 
	var oneUSdc = String(10 ** 5)
	var ERC20;
	var LendModule
	before(async function () {
		[deployer] = await ethers.getSigners();
		// console.log("deployer", deployer);

		LendModule = await ethers.getContractFactory("LendModule");
		LendModule = LendModule.connect(deployer);
		LendModule = LendModule.attach(contractData.LendModule);
		borrower = await bundler.getSender(4)
		lender = await bundler.getSender(5)
		console.log("borrower", borrower)
		console.log("lender",lender)
	});
	it.only("borrower sign", async function () {
		const value = {
				orderId: 0,
				borrower: borrower,
				lender: ethers.constants.AddressZero,
				recipient: deployer.address,
				collateralAsset:usdcToken ,//wmatic,
				collateralAmount: oneUSdc,
				borrowAsset:wmatic , //usdc
				borrowNowAmount: 0,
				borrowNowMinAmount: String(10**16),
				interestAmount:String(10**15),
				borrowLaterMinAmount: String(10**16),
				borrowLaterAmount: 0,
				expirationDate: transactionDate + 160,
				platformFee: String(10**10),
				index: 0,
				collateralAssetType:0,
				collateralNftId:0
			};
		borrowerSignature = await deployer._signTypedData(domain, types, value);
		console.log("<borrower sign data>", borrowerSignature, value)
		const recoveredAddress = ethers.utils.verifyTypedData(domain, types, value, borrowerSignature);
		console.log("recoveredAddress", recoveredAddress)

	})

	it.only("lender sign", async function () {

		// The data to sign 
		const value = {
			orderId: 0,
			borrower: borrower,
			lender: lender,
			recipient: deployer.address,
			collateralAsset: usdcToken,//wmatic,
			collateralAmount: oneUSdc,
			borrowAsset: wmatic, //usdc
			borrowNowAmount: String(10**16),
			borrowNowMinAmount: String(10**16),
			interestAmount: String(10**15),
			borrowLaterMinAmount: String(10**16),
			borrowLaterAmount: String(10**16),
			expirationDate: transactionDate + 160,
			platformFee: String(10**10),
			index: 0,
			collateralAssetType:0,
			collateralNftId:0
		};
		lenderSignature = await deployer._signTypedData(domain, types, value);
		console.log("<lender sign data>", lenderSignature, value)
		const recoveredAddress = ethers.utils.verifyTypedData(domain, types, value, lenderSignature);
		console.log("lender recoveredAddress", recoveredAddress)

	})
	it.skip("submitOrder", async function () {
		console.log("deployer.address", deployer.address)
		console.log("borrower.address", borrower)
		console.log("lender.address", lender)
		const value = {
			orderId: 0,
			borrower: borrower,
			lender: lender,
			recipient: deployer.address,
			collateralAsset: usdcToken,//wmatic,
			collateralAmount: oneUSdc,
			borrowAsset: wmatic, //usdc
			borrowNowAmount: String(10**16),
			borrowNowMinAmount: String(10**16),
			interestAmount: String(10**15),
			borrowLaterMinAmount: String(10**16),
			borrowLaterAmount: String(10**16),
			expirationDate: transactionDate + 160,
			platformFee: String(10**10),
			index: 0,
			collateralAssetType:0,
			collateralNftId:0
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
		borrower = await bundler.setSender(4);
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
		var tx = await LendModule.liquidateCallOrder(lender, true)
		console.log("<tx>", tx.hash)
	});


	async function getDeployedContract(contractName, address, libraries) {
		var contract = await ethers.getContractFactory(contractName, {libraries: libraries}, deployer);
		if (address) {
			contract = contract.attach(address);
		}
		return contract
	}

	it.skip("lender unlock", async function () {

		var VaultFacet = await getDeployedContract("VaultFacet", contractData.Diamond)
		let tx = await VaultFacet.getVaultType(lender)
		// let tx = await VaultFacet.setVaultLock(lender, false)
		console.log("setVaultLock hash",tx.hash)
	},)

});

