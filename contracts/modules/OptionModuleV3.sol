// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.12;

// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "../lib/ModuleBase.sol";
// import {IOwnable} from "../interfaces/internal/IOwnable.sol";
// import {Invoke} from "../lib/Invoke.sol";
// import {IOptionService} from "../interfaces/internal/IOptionService.sol";
// import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
// import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
// import {IOptionModuleV2} from "../interfaces/internal/IOptionModuleV2.sol";
// import {IOptionModuleV3} from "../interfaces/internal/IOptionModuleV3.sol";
// import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";
// import {INFTFreeOptionPool} from "../interfaces/external/INFTFreeOptionPool.sol";

// contract OptionModuleV3 is ModuleBase,IOptionModuleV3, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
//     modifier onlyOwner() {
//         require( msg.sender == IOwnable(diamond).owner(),"OptionModule:only owner");  
//         _;
//     }
//     struct SignData{
//         bool lock;
//         uint256 total;
//         uint256 orderCount;
//     }
//     mapping(bytes=>SignData) public signData;

//     IOptionModuleV2 optionModuleV2;
//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() {
//         _disableInitializers();
//     }

//     function initialize(address _diamond,IOptionModuleV2 _optionModuleV2) public initializer {
//         __UUPSUpgradeable_init();
//         diamond = _diamond;
//         optionModuleV2 = _optionModuleV2;
//     }

//     function _authorizeUpgrade(
//         address newImplementation
//     ) internal override onlyOwner {}



//     function submitManagedLimitOrder(IOptionModuleV3.LimitOrder memory _order)nonReentrant public{
//         verifyManagedLimitOrderSign(_order.holderOrder, _order.premiumSign,_order.holderSign);
//         IOptionFacetV2 optionFacetV2 = IOptionFacetV2(diamond);
//         IOptionFacetV2.ManagedOptionsSettings memory setting = optionFacetV2.getManagedOptionsSettingsByIndex(_order.writer,_order.settingsIndex);
//         verifyLimitSetting(setting,_order.holderOrder);
//         // IOptionModuleV2.ManagedOrder memory _info = IOptionModuleV2.ManagedOrder({
//         //     holder:_order.holderOrder.holder,
//         //     writer:setting.writer,
//         //     recipient:_order.holderOrder.recipient,
//         //     quantity:_order.holderOrder.quantity,
//         //     settingsIndex:_order.settingsIndex,
//         //     productTypeIndex:_order.productTypeIndex,
//         //     oracleIndex:_order.oracleIndex,
//         //     nftFreeOption:_order.holderOrder.nftFreeOption,
//         //     premiumSign:_order.premiumSign
//         // });
//         // optionModuleV2.handleManagedOrder(_info);
//     }



 
//     function isInArray(address[] memory array, address element) public pure returns (bool) {
//         for (uint256 i = 0; i < array.length; i++) {
//             if (array[i] == element) {
//                 return true;
//             }
//         }
//         return false;
//     }
//     function verifyManagedLimitOrderSign(ManagedLimitOrder memory _info,IOptionModuleV2.PremiumOracleSign memory _premiumSign,bytes memory _signature) internal  {
//         require(!signData[_signature].lock,"OptionModuleV2:_signature locked");
//         IOptionFacet optionFacet = IOptionFacet(diamond);
//         bytes32 infoTypeHash = keccak256(
//             " ManagedLimitOrder(address holder,address writer,address recipient,uint256 quantity,uint256 settingsIndex,uint256 productTypeIndex,uint256 oracleIndex,address nftFreeOption,uint256 maxUnderlyingAssetAmount,uint256 minUnderlyingAssetAmount,uint256 signExpireTime)"
//         );
//         bytes32 _hashInfo = keccak256(abi.encode(infoTypeHash,_info));
//         bytes32 digest = keccak256(
//             abi.encodePacked("\x19\x01", optionFacet.getDomain(), _hashInfo)
//         );
//         address signer = IVault(_info.holder).owner();
//         address recoverAddress = ECDSA.recover(digest, _signature);
//         require(recoverAddress == signer, "OptionModule:signature error");
//         if(_premiumSign.optionType == uint8(IOptionFacet.OrderType.Call)){
//             if(_info.minUnderlyingAssetAmount!=0){
//                 require(_info.minUnderlyingAssetAmount<=_premiumSign.strikeAmount,"OptionModuleV2: minUnderlyingAssetAmount error");
//             }
//             if(_info.maxUnderlyingAssetAmount!=0){
//                 require(_premiumSign.strikeAmount<= _info.maxUnderlyingAssetAmount,"OptionModuleV2: maxUnderlyingAssetAmount error");
//             }
//         }else{
//             if(_info.minUnderlyingAssetAmount!=0){
//                 require(_info.minUnderlyingAssetAmount<=_premiumSign.lockAmount,"OptionModuleV2: minUnderlyingAssetAmount error");
//             }
//             if(_info.maxUnderlyingAssetAmount!=0){
//                 require(_premiumSign.lockAmount<= _info.maxUnderlyingAssetAmount,"OptionModuleV2: maxUnderlyingAssetAmount error");
//             }
//         }
//         require(_info.productType==_premiumSign.productType,"OptionModuleV2:productType error");
//         require(_premiumSign.expireDate>= block.timestamp,"OptionModuleV2:expireDate error");
//          signData[_signature] = SignData({lock:true,total:0,orderCount:0});
//     }
//     function verifyLimitSetting(IOptionFacetV2.ManagedOptionsSettings memory _set,ManagedLimitOrder memory _info) internal pure{
//         if (_info.writer!=address(0)){
//             require(_info.writer==_set.writer,"OptionModuleV2:writer error");
//         }
//         require(_info.orderType==_set.orderType,"OptionModuleV2:orderType error");
//         require(_info.lockAsset==_set.lockAsset,"OptionModuleV2:lockAsset error");
//         require(_info.underlyingAsset==_set.underlyingAsset,"OptionModuleV2:underlyingAsset error");
//         require(_info.lockAssetType==_set.lockAssetType,"OptionModuleV2:lockAssetType error");
//         require(_info.liquidateMode==_set.liquidateMode,"OptionModuleV2:liquidateMode error");
//         require(_info.strikeAsset==_set.strikeAsset,"OptionModuleV2:strikeAsset error");
//         require(_info.premiumOracleType==_set.premiumOracleType,"OptionModuleV2:premiumOracleType error");
//     }
// }