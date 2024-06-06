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
        Signature signature;
        uint256 quantity;
        bytes  writerSign;
        PremiumOracleSign premiumSign;
    }
    struct PremiumOracleSign {
        uint64 id;              // data db id 
        uint8 productType;      // 0 degen 1 swap 2 pro
        address optionAsset;   // 0xeeee
        uint256 strikePirce;   // default 3000.00  decimal 2
        uint256 expiredate;    // option 期权过期时间
        uint8   optionType;   // 期权类型 0 call 1 put；
        address premiumAsset;  // usdt addr
        uint256 premiumFee;    // usdt amount
        uint256 timestamp;     // nowTime + 30s  default 签名有效时间
        bytes[] oracleSign;      // 0x8901... 支持多签 先连调单个签名
    }
    struct Signature {
        IOptionFacet.OrderType orderType;
        address writer;
        uint256 lockAmount;
        address lockAsset;   
        address underlyingAsset;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        uint256 underlyingNftID;
        uint256 total;
        uint256[] expirationDate;
        uint256[] lockDate;
        IOptionFacet.LiquidateMode[] liquidateModes;
        address[] strikeAssets;
        uint256[] strikeAmounts;
        address[] premiumAssets;
        uint256[] premiumFloor;
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

    event OptionPremiun(IOptionFacet.OrderType _orderType, uint64 _orderID, address _writer, address _holder, address _premiumAsset, uint256 _amount);

    function submitJvaultOrder(SubmitJvaultOrder memory _info,bytes memory _writerSignature,bytes memory _holderSignature) external;

    function submitOptionOrder(SubmitOrder memory _info,bytes memory _writerSignature) external;

}
