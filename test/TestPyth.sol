// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;
 
// import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
// import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
 
// contract TestPyth {
//   IPyth pyth=IPyth(0xff1a0f4744e8582DF1aE09D5611b887B6a12925C);
//   PythStructs.Price public  currentPrice;
//   function setPrice(bytes[] calldata priceUpdateData,bytes32 priceId) public payable  returns(PythStructs.Price memory){
//     // Update the on-chain Pyth price(s)
//     uint fee = pyth.getUpdateFee(priceUpdateData);
//     //1 wei
//     pyth.updatePriceFeeds{ value: fee }(priceUpdateData);
 
//     // Read the current price 60s
//     // bytes32 priceId = 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33;
//     PythStructs.Price memory price = pyth.getPrice(priceId);
//     currentPrice=price;
//     return price;
//   }

//   function getPrice() external view returns(PythStructs.Price memory){
//     return currentPrice;
//   }
// }
