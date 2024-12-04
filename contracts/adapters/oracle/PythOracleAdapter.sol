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
            bytes32 priceId = oralces[_masterToken][_quoteToken];
            require (priceId!=bytes32(0),"IpythAdapter:_masterToken priceId miss");
            return getPrice(priceId);
        } else {
            bytes32 priceId = oralces[_masterToken][usdToken];
            require (priceId!=bytes32(0),"IpythAdapter:_masterToken priceId miss");
            uint masterTokenPrice = getPrice(priceId);
            
            priceId = oralces[_quoteToken][usdToken];
            require (priceId!=bytes32(0),"IpythAdapter:_quoteToken priceId miss");
            uint quotaTokenPrice = getPrice(priceId);
            return  masterTokenPrice * 1 ether / quotaTokenPrice; 
        }
    }

    function getPrice(bytes32 priceId) internal view returns (uint256) {
        PythStructs.Price memory priceStruct = IPyth(pyth).getPrice(priceId);
        uint256 price;
        require(priceStruct.price>0,"IpythAdapter: getPrice price less 0");
        uint64 tempPrice = uint64(priceStruct.price);
        price = uint256(tempPrice);
        uint32 tempExpo = priceStruct.expo < 0
            ? uint32(-priceStruct.expo)
            : uint32(priceStruct.expo);
        uint256 expo = uint256(tempExpo);
        price = price * 10 ** (18 - expo);
        return price;
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
    event ReadHistoryPrice(IPriceOracle.HistoryPrice[] historyPrice);
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
                require(pythPrice.id == oralces[_masterToken][usdToken], "PythOracleAdapter:_masterToken priceIDs missMatch");
                historyPrice[i].price = getPriceByPriceFeed(pythPrice);
                historyPrice[i].timestamp = pythPrice.price.publishTime;  
            }
        }
        emit ReadHistoryPrice(historyPrice);
        return historyPrice;
    }
    function setPrice(bytes[] calldata _priceUpdateData) external{
        uint fee = IPyth(pyth).getUpdateFee(_priceUpdateData);
        IPyth(pyth).updatePriceFeeds{value: fee}(_priceUpdateData);
    }

}
