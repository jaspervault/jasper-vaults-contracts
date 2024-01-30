const {ethers} = require("hardhat");
const fs = require("fs");
const network = process.argv[process.argv.length-1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
const {bundler} = require("./sendBundler.js");

describe("LendingModule", function () {
	var deployer;
	before(async function () {
		[deployer] = await ethers.getSigners();
		LendExtension = await ethers.getContractFactory("LendExtension");
		LendExtension = LendExtension.connect(deployer);
		LendExtension = LendExtension.attach(contractData.LendExtension);
	});
	it.skip("replacementLiquidity",async function(){
		
		let decimals=6
		let decimals2=8 
		let tickNumber=58630
		const price= Math.pow(1.0001, tickNumber)

		let price_readable=  (price / Math.pow(10, decimals - decimals2))  


		price_readable=price_readable.toFixed(5)
		console.log(price_readable)


		console.log(1 / price_readable,"---2")  
		
		let ticker= Math.log(price_readable)/Math.log(1.0001)
		console.log(ticker,)  
		//--------------
        let debtor = await bundler.getSender(2)
		let calldata = LendExtension.interface.encodeFunctionData("replacementLiquidity", [
			debtor,
			0,
			500,
			-10,
			20
		]);
		await bundler.setSender(2)
		await bundler.sendBundler([contractData.LendExtension], [0], [calldata]);
	})
});
