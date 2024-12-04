// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.12;
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// import "../lib/ModuleBase.sol";

// import {IOwnable} from "../interfaces/internal/IOwnable.sol";
// import {Invoke} from "../lib/Invoke.sol";
// import {IOptionLiquidateService} from "../interfaces/internal/IOptionLiquidateService.sol";
// import {IOptionService} from "../interfaces/internal/IOptionService.sol";
// import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
// import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
// import {IOptionLiquidateHelper} from "../interfaces/internal/IOptionLiquidateHelper.sol";


// contract OptionLiquidateServiceTest is  ModuleBase,IOptionLiquidateService, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
//     using Invoke for IVault;
//     mapping(address=>bool) public liquidateWhiteList;
//     uint public ethLiquidateDecimals ;
//     IOptionLiquidateHelper public liquidateHelper ;
//     uint public maxLossRate;
//     modifier onlyOwner() {
//         require( msg.sender == IOwnable(diamond).owner(),"OptionLiquidateService:only owner");  
//         _;
//     }
//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() {
//         _disableInitializers();
//     }

//     function initialize(address _diamond) public initializer {
//         __UUPSUpgradeable_init();
//         diamond = _diamond;
//     }

//     function _authorizeUpgrade(
//         address newImplementation
//     ) internal override onlyOwner {}

//     event SetLiquidateWhiteList(address _addr,bool _ok);
//     function setLiquidateWhiteList(address _addr,bool _ok) external  onlyOwner{
//         liquidateWhiteList[_addr]=_ok;
//         emit SetLiquidateWhiteList(_addr,_ok);
//     }
//     event SetLiquidateHelper(address _addr);
//     function setLiquidateHelper(address _addr) external  onlyOwner{
//        liquidateHelper = IOptionLiquidateHelper(_addr);
//         emit SetLiquidateHelper(_addr);
//     }
//     event SetETHLiquidateDecimals(uint _decimals);
//     function setETHLiquidateDecimals(uint _decimals) external  onlyOwner{
//        ethLiquidateDecimals = _decimals;
//        emit SetETHLiquidateDecimals(_decimals);
//     }
//     event  SetMaxLossRate(uint _rate);
//     function setMaxLossRate(uint _rate) external  onlyOwner{
//        maxLossRate = _rate;
//        emit SetMaxLossRate(_rate);
//     }

    
//     //-------liquidate--------
//     function liquidateOption(
//         IOptionService.LiquidateParams calldata _params,
//         address _sender
//     ) external payable onlyModule nonReentrant returns (IOptionService.LiquidateResult memory result,Transfer[] memory transfer){
//         IOptionFacet optionFacet = IOptionFacet(diamond);
//         IVaultFacet vaultFacet = IVaultFacet(diamond);
//         if (IOptionFacet.OrderType.Call == _params._orderType) {
//             IOptionFacet.CallOrder memory order = IOptionFacet(diamond).getCallOrder(_params._orderID);          
//             require( order.holder != address(0), "OptionLiquidateService:optionOrder not exist" );  
//             LiquidateOrder memory optionOrder=LiquidateOrder({
//                         holder:order.holder,
//                         liquidateMode:order.liquidateMode,
//                         writer:order.writer,
//                         lockAssetType:order.lockAssetType,
//                         recipient:order.recipient,
//                         lockAsset:order.lockAsset,
//                         strikeAsset:order.strikeAsset,
//                         lockAmount:order.lockAmount,
//                         strikeAmount:order.strikeAmount,
//                         expirationDate:order.expirationDate,
//                         underlyingNftID:order.underlyingNftID,
//                         quantity:order.quantity
//             });
//             if ( optionOrder.liquidateMode == (IOptionFacet.LiquidateMode.PhysicalDelivery) ) {  
//                 require(_params._type != IOptionService.LiquidateType.ProfitTaking, "OptionLiquidateService:Unauthorized method of option settlement, type Error");      
//             }      
//             vaultFacet.setVaultLock(optionOrder.holder, false);
//             address owner = IVault(optionOrder.holder).owner();
           
//             if ( _sender == owner ||  (IPlatformFacet(diamond).getIsVault(_sender) &&  IOwnable(_sender).owner() == owner) ) {
//                  // amo option
//                 require(block.timestamp >= order.lockDate,"Not yet reached lockDate");
//                  (result,transfer)=handleliquidateOrder(_params,optionOrder,_sender);
//             } else if (block.timestamp >= optionOrder.expirationDate) {
//                 // euo option
//                  (result,transfer)=handleliquidateOrder(_params,optionOrder,_sender);
//             } else {
//                 revert("OptionLiquidateService:liquidate time not yet");
//             }
//             optionFacet.deleteCallOrder(_params._orderID);
//         } else {
//             IOptionFacet.PutOrder memory order = IOptionFacet(diamond).getPutOrder(_params._orderID); 
//             require(order.holder != address(0),"OptionLiquidateService:optionOrder not exist");    
//             LiquidateOrder memory optionOrder=LiquidateOrder({
//                          holder:order.holder,
//                          liquidateMode:order.liquidateMode,
//                          writer:order.writer,
//                          lockAssetType:order.lockAssetType,
//                          recipient:order.recipient,
//                          lockAsset:order.lockAsset,
//                          strikeAsset:order.strikeAsset,
//                          lockAmount:order.lockAmount,
//                          strikeAmount:order.strikeAmount,
//                          expirationDate:order.expirationDate,
//                          underlyingNftID:order.underlyingNftID,
//                         quantity:order.quantity
//             });
//             if ( optionOrder.liquidateMode == (IOptionFacet.LiquidateMode.PhysicalDelivery)  ) {     
//                 require(_params._type != IOptionService.LiquidateType.ProfitTaking, "OptionLiquidateService:Unauthorized method of option LiquidateType:ProfitTaking type Error" );     
//             }
//             if ( optionOrder.liquidateMode == (IOptionFacet.LiquidateMode.ProfitSettlement) ) {     
//                 require(_params._type != IOptionService.LiquidateType.Exercising, "OptionLiquidateService:Unauthorized method of option LiquidateType:Exercising  type Error" );     
//             }
//             vaultFacet.setVaultLock(optionOrder.holder, false);
//             address owner = IVault(optionOrder.holder).owner();
//             if ( _sender == owner || (IPlatformFacet(diamond).getIsVault(_sender) &&  IOwnable(_sender).owner() == owner) ) {  
//                 // amo option
//                 require(block.timestamp >= order.lockDate,"Not yet reached lockDate");
//                   (result,transfer)=handleliquidateOrder(_params,optionOrder,_sender);
//             } else if (block.timestamp > optionOrder.expirationDate) {
//                 // euo option
//                 require(_params._type != IOptionService.LiquidateType.Exercising, "OptionLiquidateService::Unauthorized method of option LiquidateType: Exercising " );     
//                   (result,transfer)=handleliquidateOrder(_params,optionOrder,_sender);
//             } else {
//                 revert("OptionLiquidateService:liquidate time not yet");
//             }
//             optionFacet.deletePutOrder(_params._orderID);
//         }
//         return (result,transfer);
//     }

//     function handleliquidateOrder(
//         IOptionService.LiquidateParams calldata _params,
//         LiquidateOrder memory optionOrder,
//         address _sender
//     ) internal returns(IOptionService.LiquidateResult memory result,Transfer[] memory transfers){
        
//         IPlatformFacet platformFacet = IPlatformFacet(diamond);
//         address eth = platformFacet.getEth();
//         address recipientAddr;
//         IOptionFacetV2.OptionExtra memory  extraData = IOptionFacetV2(diamond).getOptionExtraData(_params._orderID);
//         //  liquidationTo 
//         if (extraData.liquidationToEOA==true){
//             recipientAddr = IOwnable(optionOrder.holder).owner();
//          }else{
//             recipientAddr = optionOrder.recipient;
//         }
//         uint256 strikeAmount=getParts(optionOrder.quantity, optionOrder.strikeAmount);
//         uint256 lockAmount=getParts(optionOrder.quantity, optionOrder.lockAmount);
//         if (_params._type == IOptionService.LiquidateType.Exercising) {
//             transfers =  new Transfer[](2);
//             // strike asset transfer
//             transfers[0] = Transfer(
//                     optionOrder.lockAssetType,
//                     optionOrder.recipient,
//                     optionOrder.writer,
//                     optionOrder.strikeAsset,
//                     strikeAmount,
//                     0
//             );
//             updatePosition(optionOrder.recipient, optionOrder.strikeAsset, 0);
//             updatePosition(optionOrder.writer, optionOrder.strikeAsset, 0);
//             // lock asset transfer
//             transfers[1] = Transfer(
//                     optionOrder.lockAssetType,
//                     optionOrder.holder,
//                     recipientAddr,
//                     optionOrder.lockAsset,
//                     lockAmount,
//                     optionOrder.underlyingNftID
//             );
//             updatePosition(optionOrder.holder, optionOrder.lockAsset,0);       
//         } else if (_params._type == IOptionService.LiquidateType.NotExercising) {
//             require(liquidateWhiteList[_sender],"OptionLiquidateService:only whiteList can NotExercising ");
//             //unlock
//              transfers =  new Transfer[](1);
//              transfers[0] = Transfer(
//                     IOptionFacet.UnderlyingAssetType.Original,
//                     optionOrder.holder,
//                     optionOrder.writer,
//                     optionOrder.lockAsset,
//                     getParts(optionOrder.quantity, optionOrder.lockAmount),
//                     0
//                 );
//             updatePosition(optionOrder.holder, optionOrder.lockAsset, 0);
//             updatePosition(optionOrder.writer, optionOrder.lockAsset, 0);
//         } else if (_params._type ==IOptionService.LiquidateType.ProfitTaking) {
//             if ( optionOrder.lockAssetType != IOptionFacet.UnderlyingAssetType.Nft ) {  
//                 result = getEarningsAmount(
//                     GetEarningsAmount({
//                         lockAsset:optionOrder.lockAsset,
//                         lockAmount:getParts(optionOrder.quantity, optionOrder.lockAmount),
//                         strikeAsset:optionOrder.strikeAsset,
//                         strikeAmount:getParts(optionOrder.quantity, optionOrder.strikeAmount),
//                         expirationDate:optionOrder.expirationDate,
//                         index: _params._index,
//                         lockAssetPriceData: _params.lockAssetPricData,
//                         strikeAssetPriceData: _params.strikeAssetPricData,
//                         extraData: extraData,
//                         orderType:_params._orderType,
//                         sender: _sender
//                     })
//                 );
//                 // maxLoss
//                 result.amount = getMaxLossEarn(getParts(optionOrder.quantity,optionOrder.lockAmount), result.amount);
//                 transfers =  new Transfer[](2);
//                 transfers[0] = Transfer(
//                         IOptionFacet.UnderlyingAssetType.Token,
//                         optionOrder.holder,
//                         optionOrder.writer,
//                         optionOrder.lockAsset,
//                         lockAmount-result.amount,
//                         0
//                     );
//                 transfers[1] = Transfer(
//                         IOptionFacet.UnderlyingAssetType.Token,
//                         optionOrder.holder,
//                         optionOrder.writer,
//                         optionOrder.lockAsset,
//                         result.amount ,
//                         0
//                     );
//             }else{
//                 revert("OptionLiquidateService:liquidateCall LiquidateType error");
//             }
//             updatePosition(optionOrder.holder, optionOrder.lockAsset, 0);
//             updatePosition(optionOrder.writer, optionOrder.lockAsset, 0);
//             updatePosition(optionOrder.recipient, optionOrder.lockAsset, 0);
//         }
//        return  (result,transfers);
//     }

//     function getETHdecimals(address _weth)public  view returns(uint ){
//         if (ethLiquidateDecimals!=0){
//             return ethLiquidateDecimals;
//         }
//         return  IERC20(_weth).decimals();
//     }
//     function  getMaxLossEarn(uint lockAmount, uint earnAmount)internal view returns(uint earn){
//         if (lockAmount*maxLossRate / 1 ether <= earnAmount ){
//             return  lockAmount*maxLossRate;
//         }
//         return earnAmount;
//     }
//     function getEarningsAmount(
//         GetEarningsAmount memory _data
//     ) public returns (IOptionService.LiquidateResult memory result) { 
//         address eth=IPlatformFacet(diamond).getEth();
//         address weth=IPlatformFacet(diamond).getWeth();
//         uint256 lockAssetPrice;
//         uint256 strikeAssetPrice;
//         uint256 earn;
//         if (_data.extraData.optionSourceType>0){
//             require(liquidateWhiteList[_data.sender],"OptionLiquidateService:optionSourceType not support");
//         }
//         if (liquidateWhiteList[_data.sender]){
//             (lockAssetPrice,strikeAssetPrice) = liquidateHelper.whiteListLiquidatePrice(_data);
//         }else{
//             (lockAssetPrice,strikeAssetPrice) = liquidateHelper.verifyLiquidatePrice(_data);
//         }
//         // uint256 lockAssetPrice = priceOracle.getHistoryPrice(_data.lockAsset,_data.index,_data.data[0]);        
//         // uint256 strikeAssetPrice = priceOracle.getHistoryPrice(_data.strikeAsset,_data.index,_data.expirationDate,_data.data[0]);        
//         uint lockAssetDecimal = uint(_data.lockAsset == eth ? getETHdecimals(weth):IERC20(_data.lockAsset).decimals());
//         uint strikeAssetDecimal =   uint(_data.strikeAsset == eth ? getETHdecimals(weth):IERC20(_data.strikeAsset).decimals());
//         uint reversePrice =  1 ether * 1 ether / (1 ether * lockAssetPrice / strikeAssetPrice);
//         uint nowAmount = (_data.lockAmount * lockAssetPrice * 10 ** strikeAssetDecimal  )  / 10 ** lockAssetDecimal / 1 ether;
//         earn = _data.strikeAmount >= nowAmount ? 0:((nowAmount-_data.strikeAmount) * reversePrice *  10 ** lockAssetDecimal) / 10 ** strikeAssetDecimal /1 ether;
//         result.amount=earn;
//         result.lockAssetPrice=lockAssetPrice;
//         result.strikeAssetPrice=strikeAssetPrice;
//         return result;
//     }
//     function getParts(uint256 quantity ,uint256 strikeAmount)  public pure returns(uint256){
//         return quantity*strikeAmount/ 1 ether;
//     }

// }
