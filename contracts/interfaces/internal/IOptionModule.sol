// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacet} from "./IOptionFacet.sol";
import {IOptionService} from "./IOptionService.sol";
interface IOptionModule {
    struct SubmitOrder{
        uint16 strikeSelect;   
        address holder;
        uint16 liquidateSelect;  
        address writer;  
        address recipient;
        uint16  premiumSelect;
        uint256 underlyingAmount;
        Signature signature;
    }
    struct Signature {
        IOptionFacet.OrderType orderType;     
        address underlyingAsset;   
        IOptionFacet.UnderlyingAssetType underlyingAssetType;
        uint256 underlyingNftID;
        uint256 expirationDate;
        uint256 total;
        uint256 timestamp;
        IOptionFacet.LiquidateMode[] liquidateModes;
        address[] strikeAssets;
        uint256[] strikeAmounts;
        address[] premiumAssets;
        uint256[] premiumFees;  
    } 

    struct SubmitJvaultOrder{
        IOptionFacet.OrderType orderType;  
        address writer;
        IOptionFacet.UnderlyingAssetType underlyingAssetType;
        address holder;  
        address underlyingAsset;
        uint256 underlyingNftID;
        uint256 underlyingAmount;
        address strikeAsset;
        uint256 strikeAmount;
        address recipient;
        IOptionFacet.LiquidateMode liquidateMode;
        uint256 expirationDate;
        address premiumAsset;
        uint256 premiumFee;
    }

    event OptionPremiun(IOptionFacet.OrderType _orderType, uint64 _orderID, address _writer, address _holder, address _premiumAsset, uint256 _amount);

    function submitJvaultOrder(SubmitJvaultOrder memory _info,bytes memory _writerSignature,bytes memory _holderSignature) external;

    function submitOptionOrder(SubmitOrder memory _info,bytes memory _writerSignature) external;

}
