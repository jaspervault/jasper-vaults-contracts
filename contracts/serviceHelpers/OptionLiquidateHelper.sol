// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../lib/ModuleBase.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {IOptionLiquidateHelper} from "../interfaces/internal/IOptionLiquidateHelper.sol";
import {IOptionLiquidateService} from "../interfaces/internal/IOptionLiquidateService.sol";
import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";


contract OptionLiquidateHelper is  ModuleBase,IOptionLiquidateHelper, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    IPriceOracle public priceOracle;
    uint public ethLiquidateDecimals;
    modifier onlyOwner() {
        require( msg.sender == IOwnable(diamond).owner(),"OptionLiquidateService:only owner");  
        _;
    }
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _diamond,address _priceOracle) public initializer {
        __UUPSUpgradeable_init();
        diamond = _diamond;
        priceOracle=IPriceOracle(_priceOracle);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setPriceOracle(IPriceOracle _priceOracle) external  onlyOwner{
        priceOracle=_priceOracle;
    }

    function setETHLiquidateDecimals(uint _decimals) external  onlyOwner{
        ethLiquidateDecimals = _decimals;
    }

    // 10 min ;10 price ;interval > 1 min
    function whiteListLiquidatePrice( IOptionLiquidateService.GetEarningsAmount memory _data) external returns(uint lockAssetPrice,uint strikeAssetPrice) {
        if (_data.extraData.productType<=1800) {
        IPriceOracle.HistoryPrice[] memory  lockAssetHistoryPrice = priceOracle.getHistoryPrice(_data.lockAsset,_data.index,_data.lockAssetPriceData);
        IPriceOracle.HistoryPrice[] memory  strikeAssetHistoryPrice = priceOracle.getHistoryPrice(_data.strikeAsset,_data.index,_data.strikeAssetPriceData);
            // 3 min ;1 price 
            if (_data.orderType == IOptionFacet.OrderType.Call){
                require(lockAssetHistoryPrice.length == 1,'OptionLiquidateService:lockAssetHistoryPrice length 1 error');
                require(_data.expirationDate>= lockAssetHistoryPrice[0].timestamp&& lockAssetHistoryPrice[0].timestamp >= _data.expirationDate-60*3,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(strikeAssetHistoryPrice[0].timestamp >= _data.expirationDate-3600*24,"OptionLiquidateService:strikeAssetHistoryPrice time over 24 h");
            }else{
                require(strikeAssetHistoryPrice.length == 1,'OptionLiquidateService:strikeAssetHistoryPrice length 1 error');
                require(_data.expirationDate>= strikeAssetHistoryPrice[0].timestamp&&strikeAssetHistoryPrice[0].timestamp >= _data.expirationDate-60*3,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(lockAssetHistoryPrice[0].timestamp >= _data.expirationDate-3600*24,"OptionLiquidateService:lockAssetHistoryPrice time over 24 h");
            }
            return (lockAssetHistoryPrice[0].price,strikeAssetHistoryPrice[0].price);
        }else if (_data.extraData.productType<=3600*24) {
        IPriceOracle.HistoryPrice[] memory  lockAssetHistoryPrice = priceOracle.getHistoryPrice(_data.lockAsset,_data.index,_data.lockAssetPriceData);
        IPriceOracle.HistoryPrice[] memory  strikeAssetHistoryPrice = priceOracle.getHistoryPrice(_data.strikeAsset,_data.index,_data.strikeAssetPriceData);
            if (_data.orderType == IOptionFacet.OrderType.Call){
                require(lockAssetHistoryPrice.length == 3,'OptionLiquidateService:lockAssetHistoryPrice length 3 error');
                require(_data.expirationDate>= lockAssetHistoryPrice[0].timestamp&&lockAssetHistoryPrice[0].timestamp >= _data.expirationDate-60*10,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[1].timestamp&&lockAssetHistoryPrice[1].timestamp >= _data.expirationDate-60*10,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[2].timestamp&&lockAssetHistoryPrice[2].timestamp >= _data.expirationDate-60*10,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(lockAssetHistoryPrice[2].timestamp-lockAssetHistoryPrice[1].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[1].timestamp-lockAssetHistoryPrice[0].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[0].timestamp >= _data.expirationDate-3600*24,"OptionLiquidateService:strikeAssetHistoryPrice time over 24 h");
                uint[] memory price = new uint[](3);
                price[0] = lockAssetHistoryPrice[0].price;
                price[1] = lockAssetHistoryPrice[1].price;
                price[2] = lockAssetHistoryPrice[2].price;
                return (getAverage(price),strikeAssetHistoryPrice[0].price);
            }else{

                require(strikeAssetHistoryPrice.length == 3,'OptionLiquidateService:strikeAssetHistoryPrice length 3 error');
                require(_data.expirationDate>= strikeAssetHistoryPrice[0].timestamp&&strikeAssetHistoryPrice[0].timestamp >= _data.expirationDate-60*10,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[1].timestamp&&strikeAssetHistoryPrice[1].timestamp >= _data.expirationDate-60*10,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[2].timestamp&&strikeAssetHistoryPrice[2].timestamp >= _data.expirationDate-60*10,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(strikeAssetHistoryPrice[2].timestamp-strikeAssetHistoryPrice[1].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[1].timestamp-strikeAssetHistoryPrice[0].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[0].timestamp >= _data.expirationDate-3600*24,"OptionLiquidateService:lockAssetHistoryPrice time over 24 h");
                uint[] memory price = new uint[](3);
                price[0] = strikeAssetHistoryPrice[0].price;
                price[1] = strikeAssetHistoryPrice[1].price;
                price[2] = strikeAssetHistoryPrice[2].price;
                return (lockAssetHistoryPrice[0].price, getAverage(price));
            }
        }else{  
            return verifyLiquidatePrice(_data);
        }
    }
    // 10 min ;10 price ;interval >1 min
    function verifyLiquidatePrice(IOptionLiquidateService.GetEarningsAmount memory _data) public  returns(uint lockAssetPrice,uint strikeAssetPrice) {
        IPriceOracle.HistoryPrice[] memory  lockAssetHistoryPrice = priceOracle.getHistoryPrice(_data.lockAsset,_data.index,_data.lockAssetPriceData);
        IPriceOracle.HistoryPrice[] memory  strikeAssetHistoryPrice = priceOracle.getHistoryPrice(_data.strikeAsset,_data.index,_data.strikeAssetPriceData);
        if (_data.orderType == IOptionFacet.OrderType.Call){
                require(lockAssetHistoryPrice.length == 10,"price length != 10");
                require(_data.expirationDate>= lockAssetHistoryPrice[0].timestamp&&lockAssetHistoryPrice[0].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[1].timestamp&&lockAssetHistoryPrice[1].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[2].timestamp&&lockAssetHistoryPrice[2].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[3].timestamp&&lockAssetHistoryPrice[3].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[4].timestamp&&lockAssetHistoryPrice[4].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[5].timestamp&&lockAssetHistoryPrice[5].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[6].timestamp&&lockAssetHistoryPrice[6].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[7].timestamp&&lockAssetHistoryPrice[7].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[8].timestamp&&lockAssetHistoryPrice[8].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(_data.expirationDate>= lockAssetHistoryPrice[9].timestamp&&lockAssetHistoryPrice[9].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:lockAssetHistoryPrice time error");
                require(lockAssetHistoryPrice[9].timestamp-lockAssetHistoryPrice[8].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[8].timestamp-lockAssetHistoryPrice[7].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[7].timestamp-lockAssetHistoryPrice[6].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[6].timestamp-lockAssetHistoryPrice[5].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[5].timestamp-lockAssetHistoryPrice[4].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[4].timestamp-lockAssetHistoryPrice[3].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[3].timestamp-lockAssetHistoryPrice[2].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[2].timestamp-lockAssetHistoryPrice[1].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[1].timestamp-lockAssetHistoryPrice[0].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[0].timestamp >= _data.expirationDate-3600*24,"OptionLiquidateService:strikeAssetHistoryPrice time over 24 h");
                uint[] memory price = new uint[](10);
                price[0] = lockAssetHistoryPrice[0].price;
                price[1] = lockAssetHistoryPrice[1].price;
                price[2] = lockAssetHistoryPrice[2].price;
                price[3] = lockAssetHistoryPrice[3].price;
                price[4] = lockAssetHistoryPrice[4].price;
                price[5] = lockAssetHistoryPrice[5].price;
                price[6] = lockAssetHistoryPrice[6].price;
                price[7] = lockAssetHistoryPrice[7].price;
                price[8] = lockAssetHistoryPrice[8].price;
                price[9] = lockAssetHistoryPrice[9].price;
                return (getAverage(price),strikeAssetHistoryPrice[0].price);
            }else{
                require(strikeAssetHistoryPrice.length == 10,'OptionLiquidateService:strikeAssetHistoryPrice length 5 error');
                require(_data.expirationDate>= strikeAssetHistoryPrice[0].timestamp&&strikeAssetHistoryPrice[0].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[1].timestamp&&strikeAssetHistoryPrice[1].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[2].timestamp&&strikeAssetHistoryPrice[2].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[3].timestamp&&strikeAssetHistoryPrice[3].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[4].timestamp&&strikeAssetHistoryPrice[4].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[5].timestamp&&strikeAssetHistoryPrice[5].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[6].timestamp&&strikeAssetHistoryPrice[6].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[7].timestamp&&strikeAssetHistoryPrice[7].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[8].timestamp&&strikeAssetHistoryPrice[8].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(_data.expirationDate>= strikeAssetHistoryPrice[9].timestamp&&strikeAssetHistoryPrice[9].timestamp >= _data.expirationDate-60*30,"OptionLiquidateService:strikeAssetHistoryPrice time error");
                require(strikeAssetHistoryPrice[9].timestamp-strikeAssetHistoryPrice[8].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[8].timestamp-strikeAssetHistoryPrice[7].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[7].timestamp-strikeAssetHistoryPrice[6].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[6].timestamp-strikeAssetHistoryPrice[5].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[5].timestamp-strikeAssetHistoryPrice[4].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[4].timestamp-strikeAssetHistoryPrice[3].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[3].timestamp-strikeAssetHistoryPrice[2].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[2].timestamp-strikeAssetHistoryPrice[1].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(strikeAssetHistoryPrice[1].timestamp-strikeAssetHistoryPrice[0].timestamp>=60,"OptionLiquidateService:publishTime interval error");
                require(lockAssetHistoryPrice[0].timestamp >= _data.expirationDate-3600*24,"OptionLiquidateService:lockAssetHistoryPrice time over 24 h");
                uint[] memory price = new uint[](10);
                price[0] = strikeAssetHistoryPrice[0].price;
                price[1] = strikeAssetHistoryPrice[1].price;
                price[2] = strikeAssetHistoryPrice[2].price;
                price[3] = strikeAssetHistoryPrice[3].price;
                price[4] = strikeAssetHistoryPrice[4].price;
                price[5] = strikeAssetHistoryPrice[5].price;
                price[6] = strikeAssetHistoryPrice[6].price;
                price[7] = strikeAssetHistoryPrice[7].price;
                price[8] = strikeAssetHistoryPrice[8].price;
                price[9] = strikeAssetHistoryPrice[9].price;
                return (lockAssetHistoryPrice[0].price, getAverage(price));
            }
    }
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
