// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacetV2} from "./IOptionFacetV2.sol";
import {IOptionFacet} from "./IOptionFacet.sol";
import {IOptionService} from "./IOptionService.sol";
interface IOptionModuleV2 {
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
    struct PremiumOracleSign {
        uint256 id;
        uint64 productType;
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
   struct ManagedOrder{
        address holder;
        address writer;
        address recipient;
        uint256 quantity;
        uint256 index;
        uint256 oracleIndex;
        address nftFreeOption;
        PremiumOracleSign premiumSign;
    }
    event OptionPremiun(IOptionFacet.OrderType _orderType, uint64 _orderID, address _writer, address _holder, address _premiumAsset, uint256 _amount);
    event SetManagedOptionsSettings(IOptionFacetV2.ManagedOptionsSettings _newset);
    event SetOracleWhiteList(address _oracleSigner);
    event SetPriceOracle(address _priceOracleModule);

 }
