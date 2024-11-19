// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacetV2} from "./IOptionFacetV2.sol";
import {IOptionModuleV2} from "./IOptionModuleV2.sol";
import {IOptionFacet} from "./IOptionFacet.sol";
import {IOptionService} from "./IOptionService.sol";
interface IOptionModuleV3 {
    struct ManagedLimitOrder{
        address holder;
        address recipient;
        address writer;
        uint256 quantity;
        IOptionFacet.OrderType orderType;
        address lockAsset;
        address underlyingAsset;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        IOptionFacet.LiquidateMode liquidateMode;
        address strikeAsset;
        IOptionFacetV2.PremiumOracleType  premiumOracleType;
        uint256 productType;
        uint256 oracleIndex;
        address nftFreeOption;
        uint256 maxUnderlyingAssetAmount;
        uint256 minUnderlyingAssetAmount;
        uint256 signExpireTime;
    }

    struct LimitOrder{
        ManagedLimitOrder holderOrder;
        IOptionModuleV2.PremiumOracleSign premiumSign;
        bytes holderSign;
        address writer;
        uint256 settingsIndex;
        uint256 productTypeIndex;
        uint256 oracleIndex;
    }
    function submitManagedLimitOrder(LimitOrder memory _order) external;
}
