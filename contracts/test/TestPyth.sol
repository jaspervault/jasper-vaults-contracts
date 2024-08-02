// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
 
contract TestPyth {
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

    IPyth pyth=IPyth(0xff1a0f4744e8582DF1aE09D5611b887B6a12925C);
    PythStructs.Price public  currentPrice;
    function setPrice(bytes[] calldata priceUpdateData,bytes32 priceId) public payable  returns(PythStructs.Price memory){
        
    }
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint publishTime;
    }
    function getPrice(bytes32 priceId) external view returns(PythStructs.Price memory ){
        PythStructs.Price memory  c;
        if (priceId == 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace){
            // 330297910000,397428060,-8,1720015945
            c.price = 310000000000;
            c.expo = -8 ;
            return c;
        }else if( priceId == 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b){
            c.price = 99990000;
            c.expo = -8 ;
            return c;
        }else if( priceId == 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33){
            c.price = 65000*10**8;
            c.expo = -8 ;
            return c;
        }
        return c;
  }
}
