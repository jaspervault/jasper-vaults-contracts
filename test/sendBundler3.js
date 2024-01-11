const fs = require('fs');
const { ethers, upgrades, run } = require('hardhat');
const network = process.argv[process.argv.length - 1]
const sleep = require('sleep-promise');
const { SimpleAccountAPI, PaymasterAPI, HttpRpcClient } = require("@account-abstraction/sdk")
const settings = JSON.parse(fs.readFileSync(`scripts/config/${network}.json`));
const contractData = JSON.parse(fs.readFileSync(`contractData.${network}.json`));
const axios = require("axios")
let accountAPI = ""
let sender;


async function getSender(index) {
   var [deployer] = await ethers.getSigners();
   let provider = ethers.provider
   accountAPI = new SimpleAccountAPI({
      provider: provider,
      entryPointAddress: settings.entryPoint,
      owner: deployer,
      factoryAddress: contractData.VaultFactory,
      index: index
   })
   var senderTemp = await accountAPI.getCounterFactualAddress()
   return senderTemp;
}

async function setSender(index) {
   var [deployer] = await ethers.getSigners();
   let provider = ethers.provider
   accountAPI = new SimpleAccountAPI({
      provider: provider,
      entryPointAddress: settings.entryPoint,
      owner: deployer,
      factoryAddress: contractData.VaultFactory,
      index: index
   })
   sender = await accountAPI.getCounterFactualAddress()
   return sender;
}

async function sendBundler(dest, value, func) {
   var [deployer] = await ethers.getSigners();

   // let client = new HttpRpcClient(settings.bundleUrl,settings.entryPoint, settings.chainId)
   var EntryPoint = await ethers.getContractFactory("EntryPoint")
   EntryPoint = EntryPoint.connect(deployer)
   EntryPoint = EntryPoint.attach(settings.entryPoint)
   let provider = ethers.provider
   let nonce = await EntryPoint.getNonce(sender, 0)
   // console.log(nonce,"nonce")
   let code = await provider.getCode(sender)
   let initCode = "0x"
   console.log(accountAPI.index, "---")
   if (code == "0x") {
      initCode = `${contractData.VaultFactory}5fbfb9cf${String(deployer.address).substring(2).padStart(64, "0")}${String((Number(accountAPI.index)).toString(16)).padStart(64, "0")}`
   }
   let Vault = await ethers.getContractFactory("Vault")
   Vault = Vault.connect(deployer)
   Vault = Vault.attach(sender)
   let calldata = Vault.interface.encodeFunctionData("executeBatch", [dest, value, func])
   let feeData = await provider.getFeeData()
   var unsignOp = {
      sender: sender,
      nonce: nonce,
      initCode: initCode,
      callData: calldata,
      callGasLimit: 9000000,
      verificationGasLimit: 500000,
      maxFeePerGas: feeData.maxFeePerGas * 3,
      maxPriorityFeePerGas: 88640360586,
      //   paymasterAndData:"0x",
      paymasterAndData: contractData.VaultPaymaster,
      //   paymasterAndData:"0x647f1eA2ed929D2D0dC0783c1810a57501C38e36",
      preVerificationGas: 90000,
      signature: ''
   }
   //verificationGasLimit*3 + preVerificationGas + callGasLimit 
   //(500000*3 +90000+9000000) *1855652560640
   //maxFeePerGas
   var op = await accountAPI.signUserOp(unsignOp)

   let tokenUrl = `${settings.bundleUrl}/tyche/api/transact`
   op.sender = await op.sender
   op.maxFeePerGas = Number(await op.maxFeePerGas)
   op.maxPriorityFeePerGas = Number(await op.maxPriorityFeePerGas)
   op.maxFeePerGas = Number(await op.maxFeePerGas)
   op.nonce = Number(await op.nonce)
   op.verificationGasLimit = Number(op.verificationGasLimit)
   op.signature = await op.signature
   let data = {
      "address": settings.entryPoint,
      "method": "handleOps",
      "args": {
         "ops": [
            op
         ],
         "beneficiary": "0x2E4621E682272680AEAB78f48Fc0099CED79e7d6"
      }
   }

   const options = {
      method: 'POST',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({
         id: 1,
         jsonrpc: '2.0',
         method: 'eth_sendUserOperation',
         params: [
            {
               sender: op.sender,
               nonce: "0x" + (op.nonce).toString(16),
               initCode: op.initCode,
               callData: op.callData,
               callGasLimit: "0x" + (op.callGasLimit).toString(16),
               verificationGasLimit: "0x" + (op.verificationGasLimit).toString(16),
               preVerificationGas: "0x" + (op.preVerificationGas).toString(16),
               maxFeePerGas: "0x" + (op.maxFeePerGas).toString(16),
               maxPriorityFeePerGas: "0x" + (op.maxPriorityFeePerGas).toString(16),
               signature: op.signature,
               paymasterAndData: op.paymasterAndData,
            },
            '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789'

         ]
      })
   };
   console.log("<options>", options)
   let opHash
   let url = "https://eth-goerli.g.alchemy.com/v2/yqAh--po0EClIMVZNfwUnD46WdVTqeam"
   await fetch(url, options)
      .then(response => response.json())
      .then(
         response => {
            console.log("response:", response)
            opHash = response.result
         }
      )
      .catch(err => {
         console.error(err)
         return
      }
      );

   await getOperationHashV2(opHash, url, 3000, 10)
   return
   let order = await axios.post(tokenUrl, data)

   if (!order || !order.data || !order.data.data) {
      console.log("<订单错误 order>", order)
      return null
   }
   console.log("<order Id>", order.data.data.id)
   let hash = await getOperationHash(order.data.data.id, 300, 2)
   await hash.wait(1)
   console.log("<tx hash>", hash.hash)
}

async function getOperationHash(orderID, timeout, interval) {
   let orderResponse
   let hash
   const endtime = Date.now() + timeout * 1000;
   let tokenUrl = `${settings.bundleUrl}/tyche/api/order/get`
   let transaction = false
   while (Date.now() < endtime) {
      //console.log("order-----------------------------------", orderID)
      let data = {
         "orderID": String(orderID)
      }
      orderResponse = await axios.post(tokenUrl, data)
      //console.log("orderResponse", orderResponse.data)

      if (orderResponse && orderResponse.data && orderResponse.data.data && orderResponse.data.data.txHash) {
         hash = orderResponse.data.data.txHash
         while (!transaction) {
            transaction = await ethers.provider.getTransaction(hash);
            await sleep(500);
         }
         break
      }
      await new Promise((resolve) => setTimeout(resolve, interval * 1000));

   }
   return await ethers.provider.getTransaction(hash);
}



async function getOperationHashV2(opHash, url, timeout, interval) {
   const endtime = Date.now() + timeout * 1000;
   let res
   while (Date.now() < endtime) {

      const options2 = {
         method: 'POST',
         headers: { accept: 'application/json', 'content-type': 'application/json' },
         body: JSON.stringify({
            id: 1,
            jsonrpc: '2.0',
            method: 'eth_getUserOperationReceipt',
            params: [opHash]
         })
      };

      await fetch(url, options2)
         .then(response => response.json())
         .then(response => {
            console.log("hash", response)
            res = response
         })
         .catch(err => console.error(err));

      if (res.result) {
         console.log(res)
         // hash = orderResponse.data.data.txHash
         // while (!transaction) {
         //    transaction = await ethers.provider.getTransaction(hash);
         //    await sleep(500);
         // }
         break
      }
      await new Promise((resolve) => setTimeout(resolve, interval * 1000));

   }
   return await ethers.provider.getTransaction(res.result.receipt.transactionHash);
}















exports.bundler = {
   setSender,
   sendBundler,
   getSender
}