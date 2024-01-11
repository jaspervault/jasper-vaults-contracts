const {ethers} = require("hardhat");
const fs = require("fs");
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
const {bundler} = require("./sendBundler.js");
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
		{name: 'orderId', type: 'uint256'},
		{name: 'lender', type: 'address'},
		{name: 'borrower', type: 'address'},
		{name: 'recipient', type: 'address'},
		{name: 'collateralAsset', type: 'address'},
		{name: 'collateralAmount', type: 'uint256'},
		{name: 'borrowAsset', type: 'address'},
		{name: 'borrowMinAmount', type: 'uint256'},
		{name: 'borrowAmount', type: 'uint256'},
		{name: 'expirationDate', type: 'uint256'},
		{name: 'platformFee', type: 'uint256'},
		{name: 'index', type: 'uint256'},
		{name:"collateralAssetType", type:"uint256"},
        {name:"collateralNftId", type:"uint256" }
	]
};
let lenderSignature;
let borrowerSignature;
let transactionDate=parseInt(new Date().getTime()/1000)
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
		const value = {
				orderId: 0, 
				lender: ethers.constants.AddressZero,
				borrower: debtor,
				recipient: deployer.address,
				collateralAsset: settings.tokens[5].address,//wmatic
				collateralAmount: "430923722",
				borrowAsset: settings.tokens[0].address,
				borrowMinAmount: 10 ** 6,
				borrowAmount: 0,
				expirationDate: transactionDate + 3600,
				platformFee: `${10 ** 4}`,
				index: 0,
				collateralAssetType:1,
				collateralNftId:1122294
			};
		borrowerSignature = await deployer._signTypedData(domain, types, value);
		console.log("<debtor sign data>", borrowerSignature, value)
		const recoveredAddress = ethers.utils.verifyTypedData(domain, types, value, borrowerSignature);
		console.log("recoveredAddress", recoveredAddress)

	})
	it.only("loaner sign", async function () {
		// The data to sign
		const value = {
			orderId: 0,
			lender: loaner,
			borrower: debtor,
			recipient: deployer.address,
			collateralAsset: settings.tokens[5].address,//wmatic
			collateralAmount:"430923722",
			borrowAsset: settings.tokens[0].address,
			borrowMinAmount: 10 ** 6,
			borrowAmount: 10 ** 6,
			expirationDate: transactionDate + 3600,
			platformFee: `${10 ** 4}`,
			index: 0,
			collateralAssetType:1,
			collateralNftId:1122294
		};
		lenderSignature = await deployer._signTypedData(domain, types, value);
		console.log("<loaner sign data>", lenderSignature, value)

	})

	it.skip("submitOrder", async function () {
		console.log("deployer.address", deployer.address)
		console.log("loaner.address", debtor)
		console.log("debtor.address", loaner)
		var putOrder = {
			orderId: 0,
			lender:loaner,
			borrower: debtor,
			recipient: deployer.address,
			collateralAsset: settings.tokens[5].address,
			collateralAmount:"430923722",
			borrowAsset: settings.tokens[0].address,
			borrowMinAmount: 10 ** 6,
			borrowAmount: 10 ** 6,
			expirationDate: transactionDate + 3600,
			platformFee: `${10 ** 4}`,
			index: 0,
			collateralAssetType:1,
			collateralNftId:1122294
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
		var tx = await LendModule.liquidatePutOrder(debtor, true,{gasLimit:2000000})
		console.log("<tx>", tx.hash)
	});
	it.skip("replacementLiquidity",async function(){
		let decimals=6 
		let decimals2=8 
		let tickNumber=58630
		const price= Math.pow(1.0001, tickNumber)

		let price_readable=  (price / Math.pow(10, decimals - decimals2))   


		price_readable=price_readable.toFixed(5)
		console.log(1 / price_readable,"---2")  

		let ticker= Math.log(price_readable)/Math.log(1.0001)
		//--------------
		let calldata = LendModule.interface.encodeFunctionData("replacementLiquidity", [
			debtor,
			0,
			500,
			-10,
			20
		]);
		await bundler.setSender(2)
		await bundler.sendBundler([contractData.LendModule], [0], [calldata]);
	})
	it.skip("lender unlock", async function () {

		var VaultFacet = await getDeployedContract("VaultFacet", contractData.Diamond)
		// let tx = await VaultFacet.getVaultType(debtor)
		// console.log("getVaultType  ",tx,debtor)

		let tx = await VaultFacet.setVaultLock(debtor, false)
		console.log("setVaultLock hash",tx)
	},)
	async function getDeployedContract(contractName, address, libraries) {
		var contract = await ethers.getContractFactory(contractName, {libraries: libraries}, deployer);
		if (address) {
			contract = contract.attach(address);
		}
		return contract
	}
});
