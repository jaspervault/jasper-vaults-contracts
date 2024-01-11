const { ethers } = require("hardhat");
const fs = require("fs");
const network = process.argv[process.argv.length - 1]
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
const { bundler } = require("./sendBundler.js");
const { providers } = require("ethers");
let usdcToken = settings.tokens[0].address;
let wbtcToken = settings.tokens[1].address;
const domain = {
   name: settings.name,
   version: settings.version,
   chainId: settings.chainId,
   verifyingContract: contractData.LendModule
};
var tx
const types = {
   "LeveragePutOrder": [
      // { name: 'borrowerName', type: 'string' }
      { name: 'orderId', type: 'uint256' }
      // { name: 'startDate', type: 'uint256' },
      // { name: 'expirationDate', type: 'uint256' },	
      // { name: 'lender', type: 'address' },
      // { name: 'borrower', type: 'address' },
      // { name: 'recipient', type: 'address' },
      // { name: 'collateralAsset', type: 'address' },
      // { name: 'collateralAmount', type: 'uint256' },
      // { name: 'borrowAsset', type: 'address' },
      // { name: 'borrowAmount', type: 'uint256' },
      // { name: 'lockedCollateralAmount', type: 'uint256' },
      // { name: 'debtAmount', type: 'uint256' },
      // { name: 'pledgeCount', type: 'uint256' },
      // { name: 'slippage', type: 'uint256' },
      // { name: 'ltv', type: 'uint256' },
      // { name: 'platformFeeAmount', type: 'uint256' },
      // { name: 'tradeFeeAmount', type: 'uint256' },
      // { name: 'loanFeeAmount', type: 'uint256' },
      // { name: "platformFeeRate", type: "uint256" },
      // { name: "tradeFeeRate", type: "uint256" },
      // { name: "interest", type: "uint256" },
      // { name: 'index', type: 'uint256' },
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
   var Manager;
   var ERC20;
   var LendModule
   var Diamond
   var LeverageFacet
   var LeverageModule
   var deployer;
   var borrower;
   var lender;
   var oneETH = "999999999999999"
   var oneUSdc = String(10 ** 5)
   var ERC20;
   var LendModule
   let usdcToken = settings.tokens[0].address;
   let wbtcToken = settings.tokens[1].address;
   let wmatic = settings.tokens[4].address;

   var LeverageModuleTest;
   before(async function () {
      [deployer] = await ethers.getSigners();
      // console.log("deployer", deployer);
      // LendModule = await ethers.getContractFactory("LendModule");
      // LendModule = LendModule.connect(deployer);
      // LendModule = LendModule.attach(contractData.LendModule);
      // debtor = await bundler.getSender(2)
      // loaner = await bundler.getSender(3)


      // Diamond = await ethers.getContractFactory("Diamond")
      // Diamond = Diamond.connect(deployer);
      // Diamond = Diamond.attach(contractData.Diamond)
      // console.log(contractData.LeverageFacet, "----")

      LeverageFacet = await ethers.getContractFactory("LeverageFacet")
      LeverageFacet = LeverageFacet.connect(deployer);
      LeverageFacet = LeverageFacet.attach(contractData.Diamond)

      LeverageModule = await ethers.getContractFactory("LeverageModule")
      LeverageModule = LeverageModule.connect(deployer);
      LeverageModule = LeverageModule.attach(contractData.LeverageModule)


      Manager = await ethers.getContractFactory("Manager")
      Manager = Manager.connect(deployer)
      Manager = Manager.attach(contractData.Manager)



   });
   it.skip("leverageModule setWhiteList", async function () {
      tx = await LeverageModule.setWhiteList("0xa8Ad67ee2a807E631aA0aad24F658b69Ee8Bb88c", true)
      console.log(tx)
   })
   //0xC00C3d416391d0fc7129F8628F3bc20529114f2F oracle
   it.only("leverageModule setPriceOracle", async function () {
      tx = await LeverageFacet.setPriceOracle("0xC00C3d416391d0fc7129F8628F3bc20529114f2F")
      console.log(tx.hash)
   })
   it.skip("leverageModule getleverageLendPlatformFeeRecipient", async function () {
      // ILeverageFacet(diamond)
      // .getleverageLendPlatformFeeRecipient()
      tx = await LeverageFacet.interface.encodeFunctionData("getleverageLendPlatformFeeRecipient")
      tx = await Manager.multiCall([LeverageFacet.address], [tx])
      console.log(tx)
   })

   it.skip("submitOrder", async function () {
      borrower = await bundler.getSender(4)
      lender = await bundler.getSender(5)
      // const _putOrder = {
      // 	borrowerName: "jasperVault",
      // 	orderId: 73,
      // 	startDate: 1703721600,
      // 	expirationDate: 1708646400,
      // 	lender: 0x5E9B4ec899B41Cf6b8b0F61a8e583bEeC70ECfDC,
      // 	borrower: 0x77BD1844fcCA028C01b66d7132F27C4C2440634b,
      // 	recipient: 0x5c68DD54c96f34DbeeE693998D3fDF310867Ce79,
      // 	collateralAsset: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
      // 	collateralAmount: 1000000000000000000,
      // 	borrowAsset: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
      // 	borrowAmount: 1201332206,
      // 	lockedCollateralAmount: 6614388231911987000,
      // 	debtAmount: 16488354577,
      // 	pledgeCount: 10,
      // 	slippage: 30000000000000000,
      // 	ltv: 950000000000000000,
      // 	platformFeeAmount: 164883,
      // 	tradeFeeAmount: 19902,
      // 	loanFeeAmount: 164883545,
      // 	platformFeeRate: 1000000000000000,
      // 	tradeFeeRate: 3000000000000000,
      // 	interest: 10000000000000000,
      // 	index: 0
      // }
      // const _lenderData = {
      // 	lender: 0x5E9B4ec899B41Cf6b8b0F61a8e583bEeC70ECfDC,
      // 	collateralAsset: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
      // 	borrowAsset: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
      // 	minCollateraAmount: 100000000000000000,
      // 	maxCollateraAmount: 90000000000000000000,
      // 	ltv: 950000000000000000,
      // 	interest: 10000000000000000,
      // 	slippage: 30000000000000000,
      // 	pledgeCount: 10,
      // 	startDate: 1703721600,
      // 	expirationDate: 1708646400,
      // 	platformFeeRate: 1000000000000000,
      // 	tradeFeeRate: 3000000000000000
      // }
      // const _borrowerSignature = 0xb6fbfb23d5460d3f7459231c4ceccefb2f49c02d2009de818fbb8d46f61108a13933adaeb0fef6dcd3e3c2fa30b8ee3bd91cd7cbb4f4b70fed4332ac98131ee21b
      // const _lenderSignature = 0xf28fc9f83c88d544e44a671dd1db2f250b0bdfe0fa9c7124945eaf52a0d9e262061fcf77b23e6606bd5f113f031ebe306e123aa375650d7fb3a316e3fac363e61c
      // let parmas = [{
      // 	borrowerName: "jasperVault",
      // 	orderId: 73,
      // 	startDate: 1703721600,
      // 	expirationDate: 1708646400,
      // 	lender: "0x5E9B4ec899B41Cf6b8b0F61a8e583bEeC70ECfDC",
      // 	borrower: "0x77BD1844fcCA028C01b66d7132F27C4C2440634b",
      // 	recipient: "0x5c68DD54c96f34DbeeE693998D3fDF310867Ce79",
      // 	collateralAsset: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      // 	collateralAmount: "1000000000000000000",
      // 	borrowAsset: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      // 	borrowAmount: 1201332206,
      // 	lockedCollateralAmount: "6614388231911987000",
      // 	debtAmount: 16488354577,
      // 	pledgeCount: 10,
      // 	slippage: "30000000000000000",
      // 	ltv: "950000000000000000",
      // 	platformFeeAmount: 164883,
      // 	tradeFeeAmount: 19902,
      // 	loanFeeAmount: 164883545,
      // 	platformFeeRate: "1000000000000000",
      // 	tradeFeeRate: "3000000000000000",
      // 	interest: "10000000000000000",
      // 	index: 0
      // },
      // {
      // 	lender: "0x5E9B4ec899B41Cf6b8b0F61a8e583bEeC70ECfDC",
      // 	collateralAsset: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      // 	borrowAsset: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      // 	minCollateraAmount: "100000000000000000",
      // 	maxCollateraAmount: "90000000000000000000",
      // 	ltv: "950000000000000000",
      // 	interest: "10000000000000000",
      // 	slippage: "30000000000000000",
      // 	pledgeCount: 10,
      // 	startDate: 1703721600,
      // 	expirationDate: 1708646400,
      // 	platformFeeRate: "1000000000000000",
      // 	tradeFeeRate: "3000000000000000"
      // },
      // 	"0xb6fbfb23d5460d3f7459231c4ceccefb2f49c02d2009de818fbb8d46f61108a13933adaeb0fef6dcd3e3c2fa30b8ee3bd91cd7cbb4f4b70fed4332ac98131ee21b",
      // 	"0xf28fc9f83c88d544e44a671dd1db2f250b0bdfe0fa9c7124945eaf52a0d9e262061fcf77b23e6606bd5f113f031ebe306e123aa375650d7fb3a316e3fac363e61c"]
      let value = {
         // "borrowerName": "jasperVault"
         "orderId": "73"
         // "startDate": "1703721600",
         // "expirationDate": "1708646400",
         // "lender": "0x5E9B4ec899B41Cf6b8b0F61a8e583bEeC70ECfDC",
         // "borrower": "0x77BD1844fcCA028C01b66d7132F27C4C2440634b",
         // "recipient": "0x5c68DD54c96f34DbeeE693998D3fDF310867Ce79",
         // "collateralAsset": "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
         // "collateralAmount": "1000000000000000000",
         // "borrowAsset": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
         // "borrowAmount": "1201332206",
         // "lockedCollateralAmount": "6614388231911987000",
         // "debtAmount": "16488354577",
         // "pledgeCount": "10",
         // "slippage": "30000000000000000",
         // "ltv": "950000000000000000",
         // "platformFeeAmount": "164883",
         // "tradeFeeAmount": "19902",
         // "loanFeeAmount": "164883545",
         // "platformFeeRate": "1000000000000000",
         // "tradeFeeRate": "3000000000000000",
         // "interest": "10000000000000000",
         // "index": "0"
      }
      let lenderSignature = await deployer._signTypedData(domain, types, value);
      console.log("<lender sign data>", lenderSignature, domain)
      const recoveredAddress = ethers.utils.verifyTypedData(domain, types, value, lenderSignature);
      console.log("recoveredAddress", recoveredAddress)
      // function submitLeveragePutOrder(
      // 	ILeverageFacet.LeveragePutOrder memory _leveragePutOrder,
      // 	ILeverageFacet.LeveragePutLenderData calldata _lenderData,
      // 	bytes calldata _borrowerSignature,
      // 	bytes calldata _lenderSignature
      // )
      // let tx = await LeverageModule.submitLeveragePutOrder(...parmas, { gasLimit: 3000000 })
      // let calldata = LendModule.interface.encodeFunctionData("submitCallOrder", parmas);
      // console.log([contractData.LendModule], [0], [calldata])
      // await bundler.setSender(4)
      // return
      // let tx = await bundler.sendBundler([contractData.LendModule], [0], [calldata]);
      // console.log("tx", tx)
      // console.log("getTransactionCount", await ethers.provider.getTransactionCount("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"))
   })
   // it.only("leverageModule setPriceOracle", async function () {
   // 	tx = await LeverageFacet.setPriceOracle("0xC00C3d416391d0fc7129F8628F3bc20529114f2F")
   // 	console.log(tx)
   // })

})