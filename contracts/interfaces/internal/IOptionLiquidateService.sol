// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacet} from "./IOptionFacet.sol";
import {IOptionFacetV2} from "./IOptionFacetV2.sol";
import {IOptionService} from "./IOptionService.sol";
interface IOptionLiquidateService {
   
  
    struct LiquidateOrder{
        address holder;
        IOptionFacet.LiquidateMode liquidateMode;
        address writer;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        address recipient;
        address lockAsset;
        address strikeAsset;
        uint256 lockAmount;
        uint256 strikeAmount;
        uint256 expirationDate;
        uint256 underlyingNftID;
        uint256 quantity;
    }
    struct GetEarningsAmount{
        address lockAsset;
        uint256 lockAmount;
        address strikeAsset;
        uint256 strikeAmount;
        uint256 expirationDate;
        uint256 index;
        bytes[] strikeAssetPriceData;
        bytes[] lockAssetPriceData;
        IOptionFacetV2.OptionExtra extraData;
        IOptionFacet.OrderType orderType;
        address sender;
    }


    function liquidateOption(
        IOptionService.LiquidateParams memory _params,
        address _sender
    )external payable returns (IOptionService.LiquidateResult memory);
    function getParts(uint256 quantity,uint256 strikeAmount)  external view returns(uint256);
    function getEarningsAmount(GetEarningsAmount memory _data) external returns (IOptionService.LiquidateResult memory);
}