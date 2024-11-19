pragma solidity ^0.8.0;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "hardhat/console.sol";

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
    function getUpdateFee(
        bytes[] calldata updateData
    ) external view returns (uint feeAmount){
        // console.log("priceUpdateData",1);
        return 1;
    }
    IPyth pyth = IPyth(0xff1a0f4744e8582DF1aE09D5611b887B6a12925C);
    PythStructs.Price public currentPrice;

    function setPrice(
        bytes[] calldata priceUpdateData,
        bytes32 priceId
    ) public payable returns (PythStructs.Price memory) {}

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

    function getPrice(
        bytes32 priceId
    ) external view returns (PythStructs.Price memory) {
        PythStructs.Price memory c;
        // eth
        if (
            priceId ==
            0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
        ) {
            // 330297910000,397428060,-8,1720015945
            c.price = 1000 * 10 ** 8;
            c.expo = -8;
            return c;
            // usdt
        } else if (
            priceId ==
            0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b
        ) {
            c.price = 0.9999 * 10 ** 8;
            c.expo = -8;
            return c;
            // btc
        } else if (
            priceId ==
            0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33
        ) {
            c.price = 65000 * 10 ** 8;
            c.expo = -8;
            return c;
        }
        return c;
    }

    event PriceEvent(PythStructs.PriceFeed[] priceFeeds);
    function updatePriceFeeds(bytes[] calldata updateData) external payable{}
    // function parsePriceFeedUpdates(
    //     bytes[] calldata updateData,
    //     bytes32[] calldata priceIds,
    //     uint64 minPublishTime,
    //     uint64 maxPublishTime
    // ) public payable returns (PythStructs.PriceFeed[] memory priceFeeds) {
    //     uint fee = IPyth(0xff1a0f4744e8582DF1aE09D5611b887B6a12925C).getUpdateFee(updateData);
    //     priceFeeds = IPyth(0xff1a0f4744e8582DF1aE09D5611b887B6a12925C).parsePriceFeedUpdates{ value: fee }(
    //             updateData,
    //             priceIds,
    //             minPublishTime,
    //             maxPublishTime
    //         );
    //     emit PriceEvent(priceFeeds);
    //     return priceFeeds;
    // }

    function parsePriceFeedUpdatesInternal(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        PythInternalStructs.ParseConfig memory config
    ) internal returns (PythStructs.PriceFeed[] memory priceFeeds) {
        priceFeeds = new PythStructs.PriceFeed[](priceIds.length);
        // console.log("priceIds.length[i]",priceIds.length);
        for (uint i; i < priceIds.length; i++) {
            bytes32 priceId = priceIds[i];
            PythStructs.Price memory c;
            priceFeeds[i].id = priceId;
            if (
                priceId ==
                0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
            ) {
                c.price = 3234 * 10 ** 8 ;
                c.publishTime = config.minPublishTime;
                priceFeeds[i].price = c;
                // usdt
            } else if (
                priceId ==
                0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b
            ) {
                c.price = 0.9999 * 10 ** 8;
                c.expo = -8;
                c.publishTime = config.minPublishTime;
                priceFeeds[i].price = c;
                // btc
            } else if (
                priceId ==
                0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33
            ) {
                c.price = 65000 * 10 ** 8;
                c.expo = -8;
                c.publishTime = config.minPublishTime;
                priceFeeds[i].price = c;
            }
            else if (
                priceId ==
                0xff00000000000000000000000000000000000000000000000000000000000000
            ) 
            {
                c.price = 0.9999 * 10 ** 8;
                c.expo = -8;
                c.publishTime = config.minPublishTime;
                priceFeeds[i].price = c;
            }
        }
    }

    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable returns (PythStructs.PriceFeed[] memory priceFeeds) {
        return
            parsePriceFeedUpdatesInternal(
                updateData,
                priceIds,
                PythInternalStructs.ParseConfig(
                    minPublishTime,
                    maxPublishTime,
                    false
                )
            );
    }

    receive() external payable {}
}

contract PythInternalStructs {
    struct ParseConfig {
        uint64 minPublishTime;
        uint64 maxPublishTime;
        bool checkUniqueness;
    }

    struct PriceInfo {
        // slot 1
        uint64 publishTime;
        int32 expo;
        int64 price;
        uint64 conf;
        // slot 2
        int64 emaPrice;
        uint64 emaConf;
    }

    struct DataSource {
        uint16 chainId;
        bytes32 emitterAddress;
    }
}
