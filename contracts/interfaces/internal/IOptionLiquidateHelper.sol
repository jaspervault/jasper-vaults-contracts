// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionLiquidateService} from "./IOptionLiquidateService.sol";

interface IOptionLiquidateHelper {
    function whiteListLiquidatePrice( IOptionLiquidateService.GetEarningsAmount memory _data) external returns(uint lockAssetPrice,uint strikeAssetPrice) ;
    function verifyLiquidatePrice(IOptionLiquidateService.GetEarningsAmount memory _data)external  returns(uint lockAssetPrice,uint strikeAssetPrice);
}