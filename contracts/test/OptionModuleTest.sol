// // // SPDX-License-Identifier: MIT
// // pragma solidity ^0.8.12;

// // import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// // import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// // import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// // import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// // import "../lib/ModuleBase.sol";
// // import {IOwnable} from "../interfaces/internal/IOwnable.sol";
// // import {Invoke} from "../lib/Invoke.sol";
// // import {IOptionModuleV2} from "../interfaces/internal/IOptionModuleV2.sol";
// // import {IOptionService} from "../interfaces/internal/IOptionService.sol";
// // import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
// // import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
// // import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";
// // import {INFTFreeOptionPool} from "../interfaces/external/INFTFreeOptionPool.sol";

// // contract OptionModuleV2 is ModuleBase,IOptionModuleV2, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
// //     using Invoke for IVault;
// //     IOptionService public optionService;
// //     IPriceOracle priceOracleModule;

// //     struct SignData{
// //         bool lock;
// //         uint256 total;
// //         uint256 orderCount;
// //     }
// //     mapping(bytes=>SignData) public signData;
// //     mapping(address=>bool) public oracleWhiteList;
// //     // TODO: delete this
// //     mapping(address=>bool) public feeDiscountWhitlist;
    
// //     modifier onlyOwner() {
// //         require( msg.sender == IOwnable(diamond).owner(),"OptionModule:only owner");  
// //         _;
// //     }
// //     /// @custom:oz-upgrades-unsafe-allow constructor
// //     constructor() {
// //         _disableInitializers();
// //     }

// //     function initialize(address _diamond,address _optionService,address _priceOracleModule) public initializer {
// //         __UUPSUpgradeable_init();
// //         diamond = _diamond;
// //         optionService = IOptionService(_optionService);
// //         priceOracleModule = IPriceOracle(_priceOracleModule);
// //     }

// //     function _authorizeUpgrade(
// //         address newImplementation
// //     ) internal override onlyOwner {}


// //     function setOptionService(IOptionService _optionService) external onlyOwner{
// //         optionService=_optionService;
// //     }
// //     function setOracleWhiteList(address _oracleSigner) external onlyOwner{
// //         emit SetOracleWhiteList(_oracleSigner);
// //         oracleWhiteList[_oracleSigner]=true;
// //     }
// //     function setPriceOracle(IPriceOracle _priceOracleModule) external onlyOwner{
// //         emit SetPriceOracle(address(_priceOracleModule));
// //         priceOracleModule = _priceOracleModule;
// //     }

// //     function SubmitManagedOrder(ManagedOrder memory _info) external  onlyVaultOrManager(_info.holder){
// //         //verify signature
// //         IOptionFacetV2 optionFacetV2 = IOptionFacetV2(diamond);
// //         IOptionFacetV2.ManagedOptionsSettings memory setting = optionFacetV2.getManagedOptionsSettings(_info.writer);
// //         verifyManagedOrder(_info, setting);
// //         //transfer fee
// //         uint premiumFeePayed = handleManagedFee(_info, setting);
        
// //         //create order
// //         if(setting.orderType==IOptionFacet.OrderType.Call){
// //              IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
// //                 holder:_info.holder,
// //                 liquidateMode:setting.liquidateMode,
// //                 writer:setting.writer,
// //                 lockAssetType:setting.lockAssetType,
// //                 recipient:_info.recipient,
// //                 lockAsset:setting.lockAsset,
// //                 underlyingAsset:setting.underlyingAsset,
// //                 strikeAsset:setting.strikeAsset,
// //                 lockAmount:_info.premiumSign.lockAmount,
// //                 strikeAmount:_info.premiumSign.strikeAmount,
// //                 expirationDate:_info.premiumSign.expireDate,
// //                 lockDate:_info.premiumSign.lockDate,
// //                 underlyingNftID:setting.underlyingNftID,
// //                 quantity:_info.quantity
// //              });
// //              optionService.createCallOrder(callOrder);
// //             emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  setting.writer,  _info.holder, setting.premiumAssets[_info.index] ,premiumFeePayed);
// //         }else if(setting.orderType==IOptionFacet.OrderType.Put){
// //             IOptionFacet.PutOrder memory putOrder= IOptionFacet.PutOrder({
// //                         holder:_info.holder,
// //                         liquidateMode:setting.liquidateMode,
// //                         writer:setting.writer,
// //                         lockAssetType:setting.lockAssetType,
// //                         recipient:_info.recipient,
// //                         lockAsset:setting.lockAsset,
// //                         underlyingAsset:setting.underlyingAsset,
// //                         strikeAsset:setting.strikeAsset,
// //                         lockAmount:_info.premiumSign.lockAmount,
// //                         strikeAmount:_info.premiumSign.strikeAmount,
// //                         expirationDate:_info.premiumSign.expireDate,
// //                         lockDate:_info.premiumSign.lockDate,
// //                         underlyingNftID:setting.underlyingNftID,
// //                         quantity:_info.quantity
// //              });
// //              optionService.createPutOrder(putOrder);
// //             emit OptionPremiun(IOptionFacet.OrderType.Put,  IOptionFacet(diamond).getOrderId(),  setting.writer,  _info.holder, setting.premiumAssets[_info.index], premiumFeePayed);
// //         }else{
// //             revert("OptionModule:orderType error");
// //         }
// //     }
// //     //     function setSigatureLock(
// //     //     Signature memory _sign,
// //     //     bytes calldata _writerSignature
// //     // ) external onlyVaultOrManager(_sign.writer) {
// //     //     handleSignature(_sign, _sign.writer, _writerSignature);
// //     //     signData[_writerSignature].lock = true;
// //     // }

// //     // struct NewSignData{
// //     //     IOptionFacet.OrderType orderType;
// //     //     address writer;
// //     //     address lockAsset;
// //     //     address underlyingAsset;
// //     //     IOptionFacet.UnderlyingAssetType lockAssetType;
// //     //     uint256 underlyingNftID;
// //     //     uint256 total;
// //     // }
// //     // function handleSignature(
// //     //     Signature memory _signatureInfo,
// //     //     address _signer,
// //     //     bytes memory _signature
// //     // ) internal view {
// //     //     IOptionFacet optionFacet = IOptionFacet(diamond);
// //     //     bytes32 _hashInfo=getHash(_signatureInfo);
// //     //     bytes32 digest = keccak256(
// //     //         abi.encodePacked("\x19\x01", optionFacet.getDomain(), _hashInfo)
// //     //     );
// //     //     address signer = IVault(_signer).owner();
// //     //     address recoverAddress = ECDSA.recover(digest, _signature);
// //     //     require(recoverAddress == signer, "OptionModule: handleSignature signature error");
// //     // }
// //     // function getHash(Signature memory _signatureInfo) internal pure  returns(bytes32){
// //     //     bytes32 infoTypeHash = keccak256(
// //     //         "Signature(uint8 orderType,address writer,address lockAsset,address underlyingAsset,uint8 lockAssetType,uint256 underlyingNftID,uint256 total,uint256[] lockAmounts,uint256[] expirationDate,uint256[] lockDate,uint8[] liquidateModes,address[] strikeAssets,uint256[] strikeAmounts,address[] premiumAssets,uint256[] premiumRates,uint256[] premiumFloors)"
// //     //     );
// //     //     bytes32 _hashInfo = keccak256(abi.encode(
// //     //         infoTypeHash,
// //     //         getNewSignData(_signatureInfo),     
// //     //         keccak256(abi.encodePacked( _signatureInfo.lockAmounts)),
// //     //         keccak256(abi.encodePacked( _signatureInfo.expirationDate)),
// //     //         keccak256(abi.encodePacked( _signatureInfo.lockDate)),
// //     //         keccak256(abi.encodePacked( _signatureInfo.liquidateModes)),
// //     //         keccak256(abi.encodePacked( _signatureInfo.strikeAssets)),
// //     //         keccak256(abi.encodePacked( _signatureInfo.strikeAmounts)),
// //     //         keccak256(abi.encodePacked( _signatureInfo.premiumAssets)),
// //     //         keccak256(abi.encodePacked( _signatureInfo.premiumRates)),
// //     //         keccak256(abi.encodePacked( _signatureInfo.premiumFloors))
// //     //     ));
// //     //     return _hashInfo;
// //     // }
  
// //     // function getNewSignData(Signature memory _signatureInfo)internal pure returns (NewSignData memory data){
// //     //    return NewSignData(_signatureInfo.orderType,_signatureInfo.writer,_signatureInfo.lockAsset,_signatureInfo.underlyingAsset,_signatureInfo.lockAssetType,_signatureInfo.underlyingNftID,_signatureInfo.total);
// //     // }
// //     // function handleJvaultSignature(SubmitJvaultOrder memory _info,bytes memory _signature,address _signer) internal view {
// //     //     IOptionFacet optionFacet = IOptionFacet(diamond);
// //     //     bytes32 infoTypeHash = keccak256(
// //     //         "SubmitJvaultOrder(uint8 orderType,address writer,uint8 lockAssetType,address holder,address lockAsset,address underlyingAsset,uint256 underlyingNftID,uint256 lockAmount,address strikeAsset,uint256 strikeAmount,address recipient,uint8 liquidateMode,uint256 expirationDate,uint256 lockDate,address premiumAsset,uint256 premiumFee,uint256 quantity)"
// //     //     );

// //     //     bytes32 _hashInfo = keccak256(abi.encode(infoTypeHash,_info));
// //     //     bytes32 digest = keccak256(
// //     //         abi.encodePacked("\x19\x01", optionFacet.getDomain(), _hashInfo)
// //     //     );
// //     //     address signer = IVault(_signer).owner();
// //     //     address recoverAddress = ECDSA.recover(digest, _signature);
// //     //     require(recoverAddress == signer, "OptionModule:handleJvaultSignature signature error");
// //     // }
  
// //     // function handleFee(
// //     //     SubmitJvaultOrder memory _info
// //     // ) internal {
// //     //     IOptionFacet optionFacet = IOptionFacet(diamond);
// //     //     IPlatformFacet platformFacet=IPlatformFacet(diamond);
// //     //     address eth= platformFacet.getEth();
// //     //     //calculate premiumFee
// //     //     uint _premiumFee= optionService.getParts(_info.quantity, _info.premiumFee);   
// //     //     //calculate platformFee
// //     //     uint256 platformFee = (_premiumFee * optionFacet.getFeeRate()) / 1 ether;           
// //     //     address feeRecipient = optionFacet.getFeeRecipient();
// //     //     require(
// //     //         !IVaultFacet(diamond).getVaultLock(_info.recipient) &&
// //     //         !IVaultFacet(diamond).getVaultLock(_info.holder),
// //     //         "OptionModule: holder vault is locked"
// //     //     );
// //     //     require(
// //     //         platformFacet.getIsVault(_info.recipient)&&platformFacet.getIsVault(_info.holder)&&IOwnable(_info.holder).owner()==IOwnable(_info.recipient).owner(),
// //     //         "OptionModule:recipient error"
// //     //     );
// //     //     if (_info.premiumAsset == eth) {
// //     //         IVault(_info.recipient).invokeTransferEth(_info.holder, _premiumFee);
// //     //         if (platformFee > 0 && feeRecipient != address(0)) {
// //     //             IVault(_info.holder).invokeTransferEth(feeRecipient, platformFee);
// //     //         }
// //     //         IVault(_info.holder).invokeTransferEth(_info.writer, _premiumFee - platformFee);
// //     //     } else {
// //     //         IVault(_info.recipient).invokeTransfer(_info.premiumAsset, _info.holder, _premiumFee);
// //     //         if (platformFee > 0 && feeRecipient != address(0)) {
// //     //             IVault(_info.holder).invokeTransfer( _info.premiumAsset,feeRecipient,platformFee);         
// //     //         }
// //     //         IVault(_info.holder).invokeTransfer(_info.premiumAsset, _info.writer, _premiumFee - platformFee );     
// //     //     }
// //     // }
// //     function handleManagedFee(
// //         ManagedOrder memory _info,
// //         uint256 _premiumFeePayed
// //     ) internal {
// //         IOptionFacet optionFacet = IOptionFacet(diamond);
// //         IPlatformFacet platformFacet=IPlatformFacet(diamond);
// //         address eth= platformFacet.getEth();
// //         //calculate premiumFee
// //         //calculate platformFee
// //         uint256 platformFee = (_premiumFeePayed * optionFacet.getFeeRate()) / 1 ether;           
// //         address feeRecipient = optionFacet.getFeeRecipient();
// //         require(
// //             !IVaultFacet(diamond).getVaultLock(_info.recipient) &&
// //             !IVaultFacet(diamond).getVaultLock(_info.holder),
// //             "OptionModule: holder vault is locked"
// //         );
// //         require(
// //             platformFacet.getIsVault(_info.recipient)&&platformFacet.getIsVault(_info.holder)&&
// //             IOwnable(_info.holder).owner()==IOwnable(_info.recipient).owner(),
// //             "OptionModule:recipient error"
// //         );
// //         uint256 freeOptionAmount;
// //         uint256 holderPayOptionAmount;
// //         if (_info.nftFreeOption!=address(0)){
// //             uint256 freeAmount = INFTFreeOptionPool(_info.nftFreeOption).getFreeAmount(_info);
// //             if (freeAmount <= _premiumFeePayed ){
// //                 freeOptionAmount = freeAmount;
// //                 holderPayOptionAmount = _premiumFeePayed - freeAmount;
// //             }else{
// //                 freeOptionAmount = _premiumFeePayed;
// //             }
// //         }
// //         if (_info.premiumSign.premiumAsset == eth) {
// //                 if (freeOptionAmount>0){
// //                     IVault(_info.nftFreeOption).invokeTransferEth(_info.holder, freeOptionAmount);
// //                 }
// //                 if (holderPayOptionAmount>0){
// //                     IVault(_info.recipient).invokeTransferEth(_info.holder, holderPayOptionAmount);
// //                 }
// //                 if (platformFee > 0 && feeRecipient != address(0)) {
// //                     IVault(_info.holder).invokeTransferEth(feeRecipient, platformFee);
// //                 }
// //                 IVault(_info.holder).invokeTransferEth(_info.writer, _premiumFeePayed - platformFee);
// //             } else {
// //                 if (freeOptionAmount>0){
// //                     IVault(_info.nftFreeOption).invokeTransfer(_info.premiumSign.premiumAsset, _info.holder, freeOptionAmount);
// //                 }
// //                 if (holderPayOptionAmount>0){
// //                     IVault(_info.recipient).invokeTransfer(_info.premiumSign.premiumAsset, _info.holder, holderPayOptionAmount);
// //                 }
// //                 if (platformFee > 0 && feeRecipient != address(0)) {
// //                     IVault(_info.holder).invokeTransfer( _info.premiumSign.premiumAsset,feeRecipient,platformFee);         
// //                 }
// //                 IVault(_info.holder).invokeTransfer(_info.premiumSign.premiumAsset, _info.writer, _premiumFeePayed - platformFee );     
// //             }
// //             require(INFTFreeOptionPool(_info.nftFreeOption).submitFreeAmount(_info, freeOptionAmount),"OptionModule:submitFreeAmount error");
// //     }




// //     struct OptionPrice {
// //         uint256 id;
// //         uint64 productType;
// //         address optionAsset;
// //         uint256 strikePrice;
// //         address strikeAsset;
// //         uint256 strikeAmount;
// //         address lockAsset;
// //         uint256 lockAmount;
// //         uint256 expireDate;
// //         uint256 lockDate;
// //         uint8   optionType;
// //         address premiumAsset;
// //         uint256 premiumFee;
// //         uint256 timestamp;
// //     }
// //     function handlePremiumSign(
// //         PremiumOracleSign memory _sign
// //     ) internal view {
// //         OptionPrice memory data = OptionPrice(
// //             _sign.id,
// //             _sign.productType,
// //             _sign.optionAsset,
// //             _sign.strikePrice,
// //             _sign.strikeAsset,
// //             _sign.strikeAmount,
// //             _sign.lockAsset,
// //             _sign.lockAmount,
// //             _sign.expireDate,
// //             _sign.lockDate,
// //             _sign.optionType,
// //             _sign.premiumAsset,
// //             _sign.premiumFee,
// //             _sign.timestamp
// //         );
// //         bytes32 infoTypeHash = keccak256(
// //             "OptionPrice(uint256 id,uint64 productType,address optionAsset,uint256 strikePrice,address strikeAsset,uint256 strikeAmount,address lockAsset,uint256 lockAmount,uint256 expireDate,uint256 lockDate,uint8 optionType,address premiumAsset,uint256 premiumFee,uint256 timestamp)");
// //         bytes32 _hashInfo = keccak256(abi.encode(
// //                 infoTypeHash,
// //                 data
// //         ));
// //         bytes32 DomainInfoTypeHash = keccak256(
// //             "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
// //         );
// //         bytes32 _domain = keccak256(
// //             abi.encode(
// //                 DomainInfoTypeHash,
// //                 keccak256(bytes("OptionPrice")),
// //                 keccak256(bytes("v1")),
// //                 uint256(100),
// //                 0xb2891C8004c4e70EC2F65A13885EB93B7be960AF
// //             )
// //         );        
// //         bytes32 digest = keccak256(
// //             abi.encodePacked("\x19\x01", _domain, _hashInfo)
// //         );
// //         for(uint i; i<_sign.oracleSign.length; i++) {
// //             require(oracleWhiteList[ECDSA.recover(digest, _sign.oracleSign[i])], "OptionModule:handlePremiumSign not from whiteList error");
// //         }
// //     }    
// //     function isInArray(address[] memory array, address element) public pure returns (bool) {
// //         for (uint i = 0; i < array.length; i++) {
// //             if (array[i] == element) {
// //                 return true;
// //             }
// //         }
// //         return false;
// //     }

// //     function verifyManagedOrder(ManagedOrder memory _info, IOptionFacetV2.ManagedOptionsSettings memory _setting) internal view{
// //         require(_setting.isOpen, "OptionModule:isOpen error");
// //         require(!IVaultFacet(diamond).getVaultLock(_info.recipient)&&
// //                 !IVaultFacet(diamond).getVaultLock(_info.holder)&&
// //                 !IVaultFacet(diamond).getVaultLock(_info.writer),
// //                 "OptionModule:vault is locked");
// //         require(_setting.writer == _info.writer,"OptionModule:writer error");
// //         require(uint8(_setting.orderType) == _info.premiumSign.optionType,"OptionModule:optionType mismatch");
// //         require(_setting.lockAsset == _info.premiumSign.lockAsset,"OptionModule:lockAsset mismatch");
// //         require(_setting.underlyingAsset == _info.premiumSign.optionAsset,"OptionModule:underlyingAsset mismatch");
// //         require(_setting.strikeAsset == _info.premiumSign.strikeAsset,"OptionModule:strikeAsset mismatch");
// //         require(isInArray(_setting.premiumAssets,_info.premiumSign.premiumAsset),"OptionModule:premiumAsset mismatch");
// //         require(_setting.maximum>=_info.quantity, "OptionModule:productType error");
// //         require(_setting.productTypes[_info.index] == _info.premiumSign.productType, "OptionModule:productType error");
// //         require(_info.premiumSign.strikeAmount >0, "OptionModule:strikeAmount error");
// //         require(_info.premiumSign.timestamp<= block.timestamp , "OptionModule:PremiumOracleSign timestamp expired");
// //         require(feeDiscountWhitlist[_info.nftFreeOption], "OptionModule: nftFreeOption error");
// //         handlePremiumSign(_info.premiumSign);
// //     }

// //     function setManagedOptionsSettings(IOptionFacetV2.ManagedOptionsSettings memory _set) external onlyVaultOrManager(_set.writer){
// //         require(!IVaultFacet(diamond).getVaultLock(_set.writer),"OptionModule:writer is locked");
// //         IOptionFacetV2(diamond).setManagedOptionsSettings(_set);
// //     }
// //     function handleManagedFee(ManagedOrder memory _info,IOptionFacetV2.ManagedOptionsSettings memory setting ) internal returns(uint256){
// //         uint256 premiumFeePayed;
// //         address eth = IPlatformFacet(diamond).getEth();
// //         address weth = IPlatformFacet(diamond).getWeth();
// //         uint256 premiumAssetPrice =  priceOracleModule.getUSDPriceSpecifyOracle(
// //             _info.premiumSign.premiumAsset == eth ? weth :  _info.premiumSign.premiumAsset,
// //             _info.oracleIndex);
// //         uint premiumDecimals =  uint(IERC20(_info.premiumSign.premiumAsset == eth ? weth : _info.premiumSign.premiumAsset).decimals());
// //         uint floorPremiumAmount =  10**36/premiumAssetPrice * setting.premiumFloorUSDs[_info.index] / 1 ether * 10**premiumDecimals/ 1 ether; 

// //         if (setting.premiumOracleType==IOptionFacetV2.PremiumOracleType.AMMS){
// //             uint256 premiumUSD = setting.premiumRates[_info.index] * priceOracleModule.getUSDPriceSpecifyOracle(setting.lockAsset == eth ? weth : setting.lockAsset, _info.oracleIndex) *_info.premiumSign.lockAmount /1 ether / 1 ether;
// //             uint premiumAmount = 10**36/premiumAssetPrice* premiumUSD / 1 ether * 10**premiumDecimals / 10** uint(IERC20(setting.lockAsset == eth ? weth : setting.lockAsset).decimals());
// //             premiumFeePayed=premiumAmount*premiumAssetPrice/ 10**premiumDecimals >= setting.premiumFloorUSDs[_info.index] ? premiumAmount :floorPremiumAmount ;
// //         }else if(setting.premiumOracleType==IOptionFacetV2.PremiumOracleType.PAMMS){
// //             uint premiumAmount = _info.premiumSign.premiumFee*setting.premiumRates[_info.index] / 1 ether;
// //             premiumFeePayed=premiumAmount*premiumAssetPrice/ 10**premiumDecimals >= setting.premiumFloorUSDs[_info.index] ? premiumAmount :floorPremiumAmount ;
// //         }
// //         premiumFeePayed =  optionService.getParts(_info.quantity,premiumFeePayed);
// //         handleManagedFee(_info,premiumFeePayed);
// //         return premiumFeePayed;
// //     }
// // }


// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "../lib/ModuleBase.sol";
// import {IOwnable} from "../interfaces/internal/IOwnable.sol";
// import {Invoke} from "../lib/Invoke.sol";
// import {IOptionModuleV2} from "../interfaces/internal/IOptionModuleV2.sol";
// import {IOptionModuleV3} from "../interfaces/internal/IOptionModuleV3.sol";
// import {IOptionService} from "../interfaces/internal/IOptionService.sol";
// import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
// import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
// import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";
// import {INFTFreeOptionPool} from "../interfaces/external/INFTFreeOptionPool.sol";

// contract OptionModuleV3 is ModuleBase, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
//     using Invoke for IVault;
//     modifier onlyOwner() {
//         require( msg.sender == IOwnable(diamond).owner(),"OptionModule:only owner");  
//         _;
//     }
//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() {
//         _disableInitializers();
//     }

//     function initialize(address _diamond,address _optionService,address _priceOracleModule) public initializer {
//         __UUPSUpgradeable_init();
//         diamond = _diamond;
//     }

//     function _authorizeUpgrade(
//         address newImplementation
//     ) internal override onlyOwner {}


//     function submitManagedLimitOrder(IOptionModuleV3.LimitOrder memory _order)nonReentrant public{
//         verifyManagedLimitOrderSign(_order.holderOrder, _order.premiumSign,_order.holderSign);
//         IOptionFacetV2 optionFacetV2 = IOptionFacetV2(diamond);
//         IOptionFacetV2.ManagedOptionsSettings memory setting = optionFacetV2.getManagedOptionsSettingsByIndex(_order.writer,_order.settingsIndex);
//         verifyLimitSetting(setting,_order.holderOrder);
//         IOptionModuleV2.ManagedOrder memory _info = IOptionModuleV2.ManagedOrder({
//             holder:_order.holderOrder.holder,
//             writer:setting.writer,
//             recipient:_order.holderOrder.recipient,
//             quantity:_order.holderOrder.quantity,
//             settingsIndex:_order.settingsIndex,
//             productTypeIndex:_order.productTypeIndex,
//             oracleIndex:_order.oracleIndex,
//             nftFreeOption:_order.holderOrder.nftFreeOption,
//             premiumSign:_order.premiumSign
//         });
//         verifyManagedOrder(_info, setting);
//         //transfer fee
//         uint256 premiumFeeToPay = transferManagedFee(_info, setting);
        
//         // //create order
//         if(setting.orderType==IOptionFacet.OrderType.Call){
//              IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
//                 holder:_info.holder,
//                 liquidateMode:setting.liquidateMode,
//                 writer:setting.writer,
//                 lockAssetType:setting.lockAssetType,
//                 recipient:_info.recipient,
//                 lockAsset:setting.lockAsset,
//                 underlyingAsset:setting.underlyingAsset,
//                 strikeAsset:setting.strikeAsset,
//                 lockAmount:_info.premiumSign.lockAmount,
//                 strikeAmount:_info.premiumSign.strikeAmount,
//                 expirationDate:_info.premiumSign.expireDate,
//                 lockDate:_info.premiumSign.lockDate,
//                 underlyingNftID:setting.underlyingNftID,
//                 quantity:_info.quantity
//              });
//              optionService.createCallOrder(callOrder);
//             emit OptionPremiun(IOptionFacet.OrderType.Call, IOptionFacet(diamond).getOrderId(),  setting.writer,  _info.holder, _info.premiumSign.premiumAsset ,premiumFeeToPay);
//         }else if(setting.orderType==IOptionFacet.OrderType.Put){
//             IOptionFacet.PutOrder memory putOrder= IOptionFacet.PutOrder({
//                         holder:_info.holder,
//                         liquidateMode:setting.liquidateMode,
//                         writer:setting.writer,
//                         lockAssetType:setting.lockAssetType,
//                         recipient:_info.recipient,
//                         lockAsset:setting.lockAsset,
//                         underlyingAsset:setting.underlyingAsset,
//                         strikeAsset:setting.strikeAsset,
//                         lockAmount:_info.premiumSign.lockAmount,
//                         strikeAmount:_info.premiumSign.strikeAmount,
//                         expirationDate:_info.premiumSign.expireDate,
//                         lockDate:_info.premiumSign.lockDate,
//                         underlyingNftID:setting.underlyingNftID,
//                         quantity:_info.quantity
//              });
//              optionService.createPutOrder(putOrder);
//             emit OptionPremiun(IOptionFacet.OrderType.Put,IOptionFacet(diamond).getOrderId(),setting.writer,_info.holder,_info.premiumSign.premiumAsset,premiumFeeToPay);
//         }else{
//             revert("OptionModule:orderType error");
//         }
//     }


//     function verifyManagedLimitOrderSign(IOptionModuleV3.ManagedLimitOrder memory _info,IOptionModuleV2.PremiumOracleSign memory _premiumSign,bytes memory _signature) internal  {
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
//         signData[_signature] = SignData({lock:true,total:0,orderCount:0});
//     }
//     function verifyLimitSetting(IOptionFacetV2.ManagedOptionsSettings memory _set,IOptionModuleV3.ManagedLimitOrder memory _info) internal view{
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