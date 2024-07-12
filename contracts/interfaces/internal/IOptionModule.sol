// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacet} from "./IOptionFacet.sol";
import {IOptionService} from "./IOptionService.sol";
interface IOptionModule {
    struct SubmitOrder{
        uint16 optionSelect;   
        address holder;
        address writer;  
        address recipient;
        uint256 quantity;
        Signature signature;
        bytes  writerSign;
        PremiumOracleSign premiumSign;
    }
    struct PremiumOracleSign {
        uint256 id;
        uint8 productType;
        address optionAsset;
        uint256 strikePrice;
        address strikeAsset;
        uint256 strikeAmount;
        address lockAsset;
        uint256 lockAmount;
        uint256 expireDate;
        uint256 lockDate;
        uint8   optionType;
        address premiumAsset;
        uint256 premiumFee;
        uint256 timestamp;
        bytes[] oracleSign;
    }

    struct Signature {
        IOptionFacet.OrderType orderType;
        address writer;
        address lockAsset;
        address underlyingAsset;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        uint256 underlyingNftID;
        uint256 total;
        uint256[] lockAmounts;
        uint256[] expirationDate;
        uint256[] lockDate;
        IOptionFacet.LiquidateMode[] liquidateModes;
        address[] strikeAssets;
        uint256[] strikeAmounts;
        address[] premiumAssets;
        uint256[] premiumRates;
        uint256[] premiumFloors;
    } 

    struct SubmitJvaultOrder{
        IOptionFacet.OrderType orderType;  
        address writer;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        address holder;  
        address lockAsset;
        address underlyingAsset;
        uint256 underlyingNftID;
        uint256 lockAmount;
        address strikeAsset;
        uint256 strikeAmount;
        address recipient;
        IOptionFacet.LiquidateMode liquidateMode;
        uint256 expirationDate;
        uint256 lockDate;
        address premiumAsset;
        uint256 premiumFee;
        uint256 quantity;
    }
    struct ManagedOrder{
        address holder;
        address writer;
        address recipient;
        uint256 quantity;
        uint256 index;
        uint256 oracleIndex;
        PremiumOracleSign premiumSign;
    }
    event OptionPremiun(IOptionFacet.OrderType _orderType, uint64 _orderID, address _writer, address _holder, address _premiumAsset, uint256 _amount);
    event SetManagedOptionsSettings(IOptionFacet.ManagedOptionsSettings _newset);
}
