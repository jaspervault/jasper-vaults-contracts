// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IOwnable} from "../../interfaces/internal/IOwnable.sol";
import {IOracleAdapter} from "../../interfaces/internal/IOracleAdapter.sol";
import {IPriceOracle} from "../../interfaces/internal/IPriceOracle.sol";
import {IOracleAdapterV2} from "../../interfaces/internal/IOracleAdapterV2.sol";
import {IPythAdapter} from "../../interfaces/internal/IPythAdapter.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "hardhat/console.sol";

contract PythOracleAdapter is
    IOracleAdapter,
    IOracleAdapterV2,
    Initializable,
    UUPSUpgradeable
{
    address public diamond;
    address public pyth;
    mapping(address => mapping(address => bytes32)) public oralces;
    address public usdToken;
    event SetOralces(
        address[] _masterTokens,
        address[] _quoteTokens,
        bytes32[] _oracles
    );

    modifier onlyOwner() {
        require(msg.sender == IOwnable(diamond).owner(), "only owner");
        _;
    }

    receive() external payable {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _diamond,
        address _pyth,
        address _usdToken
    ) public initializer {
        diamond = _diamond;
        usdToken = _usdToken;
        pyth = _pyth;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setPyth(address _addr) external onlyOwner {
        pyth = _addr;
    }

    function setOralceList(
        address[] memory _masterTokens,
        address[] memory _quoteTokens,
        bytes32[] memory _oracles
    ) external onlyOwner {
        for (uint i; i < _quoteTokens.length; i++) {
            require(
                _quoteTokens[i] == usdToken,
                "ChainLinkOracleAdapter:quoteToken error"
            );
            oralces[_masterTokens[i]][_quoteTokens[i]] = _oracles[i];
        }
        emit SetOralces(_masterTokens, _quoteTokens, _oracles);
    }

    function read(
        address _masterToken,
        address _quoteToken
    ) external view returns (uint256) {
        if (_quoteToken == usdToken) {
            uint256 price = getPriceByBase(_masterToken, _quoteToken);
            if (price == 0) {
                price = getPriceByUsd(_masterToken, _quoteToken);
            }
            return price;
        } else {
            uint256 firstPrice = getPriceByBase(_masterToken, usdToken);
            if (firstPrice == 0) {
                firstPrice = getPriceByUsd(_masterToken, usdToken);
            }
            firstPrice = firstPrice / 10 ** 10;
            require(
                firstPrice != 0,
                "PythOracleAdapter Error:_masterToken token priceId Miss "
            );
            uint256 secondPrice = getPriceByBase(_quoteToken, usdToken);
            if (secondPrice == 0) {
                secondPrice = getPriceByUsd(_quoteToken, usdToken);
            }
            require(
                secondPrice != 0,
                "PythOracleAdapter Error:_quoteToken token priceId Miss "
            );
            secondPrice = secondPrice / 10 ** 10;
            return (firstPrice * 1 ether) / secondPrice;
        }
    }

    function getPriceByBase(
        address _masterToken,
        address _quoteToken
    ) internal view returns (uint256) {
        bytes32 priceId = oralces[_masterToken][_quoteToken];
        if (priceId == bytes32(0)) {
            return 0;
        }
        return getPrice(priceId);
    }

    function getPrice(bytes32 priceId) internal view returns (uint256) {
        PythStructs.Price memory priceStruct = IPyth(pyth).getPrice(priceId);
        uint256 price;
        if (priceStruct.price <= 0) {
            price = 0;
        } else {
            uint64 tempPrice = uint64(priceStruct.price);
            price = uint256(tempPrice);
        }
        uint32 tempExpo = priceStruct.expo < 0
            ? uint32(-priceStruct.expo)
            : uint32(priceStruct.expo);
        uint256 expo = uint256(tempExpo);
        price = price * 10 ** (18 - expo);
        return price;
    }

    function getPriceByUsd(
        address _masterToken,
        address _quoteToken
    ) internal view returns (uint256) {
        bytes32 masterId = oralces[_masterToken][usdToken];
        bytes32 quoteId = oralces[_quoteToken][usdToken];
        if (masterId == bytes32(0) || quoteId == bytes32(0)) {
            return 0;
        }
        uint256 masterPrice = getPrice(masterId);
        uint256 quotePrice = getPrice(quoteId);
        return (masterPrice * 1 ether) / quotePrice;
    }

    function getPriceByPriceFeed(
        PythStructs.PriceFeed memory _priceFeed
    ) internal pure returns (uint256) {
        require(_priceFeed.price.price > 0, "PythOracleAdapter:price get 0");
        uint256 price = uint256(uint64(_priceFeed.price.price));
        uint32 expo = _priceFeed.price.expo < 0
            ? uint32(-_priceFeed.price.expo)
            : uint32(_priceFeed.price.expo);
        price = price * 10 ** (18 - expo);
        return (price);
    }

    function decode(
        bytes memory _data
    ) internal pure returns (IPythAdapter.PythData memory pythDatas) {
        return abi.decode(_data, (IPythAdapter.PythData));
    }

    function parsePriceFeedData(
        address _masterToken,
        address _quoteToken,
        uint256 _publishTime,
        IPythAdapter.PythData memory _pythData,
        uint _fee
    ) internal returns (uint price, uint publishTime) {
        // publishTime = priceFeed[0].price.publishTime;
        // require(priceFeed.length==2,"PythOracleAdapter:length error");
        // require(priceFeed[0].id==oralces[_masterToken][usdToken], "PythOracleAdapter:_masterToken priceIDs missMatch");
        // if (_quoteToken == usdToken){
        //    price=getPriceByPriceFeed(priceFeed[0],_publishTime);
        // }else{
        //     require(priceFeed[1].id == oralces[_quoteToken][usdToken], "PythOracleAdapter:_quoteToken priceIDs missMatch");
        //     uint mastePrice = getPriceByPriceFeed(priceFeed[0],_publishTime);
        //     uint quotePrice = getPriceByPriceFeed(priceFeed[1],_publishTime);
        //    price = mastePrice * 1 ether / quotePrice;
        // }
    }

    function getHistoryPriceFromPyth(
        uint _fee,
        IPythAdapter.PythData memory _pythData
    ) public returns (PythStructs.PriceFeed[] memory priceFeed)  {
        priceFeed = IPyth(pyth)
            .parsePriceFeedUpdates{value: _fee}(
            _pythData.updateData,
            _pythData.priceIds,
            _pythData.minPublishTime,
            _pythData.maxPublishTime
        );
        return priceFeed;
    }



    // Main function to read history price
    function readHistoryPrice(
        address _masterToken,
        bytes[] memory _data
    ) external returns (IPriceOracle.HistoryPrice[] memory historyPrice) {
        uint len = _data.length;
        historyPrice = new IPriceOracle.HistoryPrice[](len);
        for (uint i; i <len; i++) {
            (IPythAdapter.PythData memory pythDataStruct) = abi.decode(_data[i], (  IPythAdapter.PythData));
            uint fee = IPyth(pyth).getUpdateFee(pythDataStruct.updateData);
            PythStructs.PriceFeed[] memory pythPriceList = getHistoryPriceFromPyth(fee, pythDataStruct);
            require(pythPriceList.length != 0, "PythOracleAdapter:length missMatch");
            for (uint p;p< pythPriceList.length;p++){
                PythStructs.PriceFeed memory pythPrice = pythPriceList[p];
                console.logBytes32(pythPrice.id);
                console.logBytes32(oralces[_masterToken][usdToken]);
                require(pythPrice.id == oralces[_masterToken][usdToken], "PythOracleAdapter:_masterToken priceIDs missMatch");
                historyPrice[i].price = getPriceByPriceFeed(pythPrice);
                historyPrice[i].timestamp = pythPrice.price.publishTime;  
            }
        }
        return historyPrice;
    }
    function sliceBytes(bytes memory data, uint start, uint end) pure public returns (bytes memory) {
        require(end > start, "End must be greater than start");
        require(data.length >= end, "End must be within bounds");

        bytes memory result = new bytes(end - start);
        uint step = end - start;

        assembly {
            // Calculate the source and destination pointers
            let src := add(data, add(0x20, start)) // Start at 32 bytes offset plus start
            let dest := add(result, 0x20) // Result data starts after length prefix

            // Calculate the last of the source slice
            let last := add(src, step)

            for { } lt(src, last) { 
                src := add(src, 0x20)
                dest := add(dest, 0x20)
            } {
                mstore(dest, mload(src))
            }
        }

        return result;
    }

    
    // Function to decode multiple PythData from bytes
    // function decodePythDataBatch(bytes memory data) public pure returns (IPythAdapter.PythData[] memory) {
    //     uint256 offset = 0;
    //     // 从数据中获取结构体数量
    //     uint256 count;
    //     assembly {
    //         count := mload(add(data, 32))
    //     }
    //     offset += 32;

    //     IPythAdapter.PythData[] memory pythData = new IPythAdapter.PythData[](count);

    //     for (uint256 i = 0; i < count; i++) {
    //         (
    //             bytes[] memory updateData,
    //             bytes32[] memory priceIds,
    //             uint64 minPublishTime,
    //             uint64 maxPublishTime,
    //             uint256 newOffset
    //         ) = _decodeSinglePythData(data, offset,count);
    //         pythData[i] = IPythAdapter.PythData({
    //             updateData: updateData,
    //             priceIds: priceIds,
    //             minPublishTime: minPublishTime,
    //             maxPublishTime: maxPublishTime
    //         });
    //         offset = newOffset;
    //     }
    //     return pythData;
    // }


    // function _decodeSinglePythData(
    //     bytes memory data,
    //     uint256 offset

    // ) internal pure returns (
    //     bytes[] memory updateData,
    //     bytes32[] memory priceIds,
    //     uint64 minPublishTime,
    //     uint64 maxPublishTime,
    //     uint256 newOffset
    // ) {
    // // uint step = 1600;
    // uint256 step;
    // assembly {
    //     step := mload(add(data, add(offset,32)))
    // }
    // offset += 32;
    // bytes memory pythData = sliceBytes(data,offset,step+offset);
    // (IPythAdapter.PythData memory path) = abi.decode(pythData, ( IPythAdapter.PythData));   
    // return (path.updateData, path.priceIds, path.minPublishTime, path.maxPublishTime, step+offset);
    // }

// // Function to decode single PythData
// function _decodeSinglePythData(
//     bytes memory data,
//     uint256 offset
// )
//     internal
//     pure
//     returns (
//         bytes[] memory updateData,
//         bytes32[] memory priceIds,
//         uint64 minPublishTime,
//         uint64 maxPublishTime,
//         uint256 newOffset
//     )
// {
//     uint updateDataLength;
//     uint updateDataOffset = offset + 32;  // 初始偏移量
//     assembly {
//         // 解码 updateData 数组的长度
//         updateDataLength := mload(add(data, offset))
//     }

//     updateData = new bytes[](updateDataLength);

//     // 解码 updateData 数组
//     for (uint i = 0; i < updateDataLength; i++) {
//         uint byteDataOffset = updateDataOffset + i * 32;
//         assembly {
//             mstore(add(updateData, mul(add(i, 1), 32)), mload(add(data, byteDataOffset)))
//         }
//     }

//     // 更新 updateData 后，更新偏移量
//     updateDataOffset = updateDataOffset + updateDataLength * 32;  // 每个元素占32字节，更新偏移量

//     // 计算 priceIds 的偏移量
//     uint priceIdsOffset;
//     assembly {
//         priceIdsOffset := add(updateDataOffset, mul(updateDataLength, 32))
//     }

//     // 解码 priceIds 数组的长度
//     uint priceIdsLength;
//     assembly {
//         priceIdsLength := mload(add(data, priceIdsOffset))
//     }

//     priceIdsOffset = priceIdsOffset + 32; // 更新偏移量

//     // 解码 priceIds
//     priceIds = new bytes32[](priceIdsLength);
//     for (uint i = 0; i < priceIdsLength; i++) {
//         assembly {
//             mstore(add(priceIds, mul(add(i, 1), 32)), mload(add(data, add(priceIdsOffset, mul(i, 32)))))
//         }
//     }

//     // 解码 minPublishTime 和 maxPublishTime
//     uint64 _minPublishTime;
//     uint64 _maxPublishTime;
//     assembly {
//         _minPublishTime := mload(add(data, priceIdsOffset))
//         _maxPublishTime := mload(add(data, add(priceIdsOffset, 32)))
//     }

//     // 更新偏移量
//     newOffset = priceIdsOffset + 64;

//     return (updateData, priceIds, _minPublishTime, _maxPublishTime, newOffset);
// }


    // function readV2(address _masterToken,bytes memory _data)external returns (HistoryPrice[] memory price) {
    //     IPythAdapter.SummaryPythData memory pythDatas = decode(_data);
    //     uint fee = IPyth(pyth).getUpdateFee(pythDatas.price1.updateData);
    //     uint[] memory priceList = new uint[](3);
    //     (uint _price1,uint _publishTime1) =  parsePriceFeedData(_masterToken,_quoteToken,pythDatas.price1,fee);
    //     (uint _price2,uint _publishTime2) =  parsePriceFeedData(_masterToken,_quoteToken,pythDatas.price2,fee);
    //     (uint _price3,uint _publishTime3) =  parsePriceFeedData(_masterToken,_quoteToken,pythDatas.price3,fee);
    //     require(_publishTime3-_publishTime2>=60,"PythOracleAdapter:publishTime interval error");
    //     require(_publishTime2-_publishTime1>=60,"PythOracleAdapter:publishTime interval error");
    //     priceList[0] = _price1;
    //     priceList[1] = _price2;
    //     priceList[2] = _price3;
    //     return getAverage(priceList);
    // }

    function getAverage(uint[] memory array) public pure returns (uint) {
        uint sum = 0;
        require(array.length > 0, "Array length must be greater than 0");
        for (uint i = 0; i < array.length; i++) {
            sum += array[i];
        }
        uint average = sum / array.length;
        return average;
    }
}
