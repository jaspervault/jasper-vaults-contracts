// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacet} from "./IOptionFacet.sol";
interface IOptionFacetV2 {
    enum PremiumOracleType {
        PAMMS,
        AMMS
    }
    struct ManagedOptionsSettings {
        bool isOpen;
        IOptionFacet.OrderType orderType;
        address writer;
        address lockAsset;
        address underlyingAsset;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        uint256 underlyingNftID;
        IOptionFacet.LiquidateMode liquidateMode;
        address strikeAsset;
        uint256 maximum;
        PremiumOracleType  premiumOracleType;
        address[] premiumAssets;
        uint64[]   productTypes;    // 1h=3600 2h=7200
        uint256[]  premiumFloorUSDs;// 10u = 10 ether
        uint256[]  premiumRates;    // 1.1 ether 0.9 ether
    }
    event SetManagedOptionsSettings(ManagedOptionsSettings set);

    function getManagedOptionsSettings(address _vault) external view returns(IOptionFacetV2.ManagedOptionsSettings memory set);
    function setManagedOptionsSettings(ManagedOptionsSettings memory set) external;
}
