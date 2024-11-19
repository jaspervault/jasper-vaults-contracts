// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../lib/ModuleBase.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {Invoke} from "../lib/Invoke.sol";
import {IOptionLiquidateService} from "../interfaces/internal/IOptionLiquidateService.sol";
import {IOptionService} from "../interfaces/internal/IOptionService.sol";
import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
import {INonfungiblePositionManager} from "../interfaces/external/INonfungiblePositionManager.sol";
import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
import {IPythAdapter} from "../interfaces/internal/IPythAdapter.sol";
import {IOptionLiquidateHelper} from "../interfaces/internal/IOptionLiquidateHelper.sol";
import "hardhat/console.sol";

contract OptionLiquidateService is  ModuleBase,IOptionLiquidateService, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    using Invoke for IVault;
    mapping(address=>bool) public liquidateWhiteList;
    uint ethLiquidateDecimals ;
    IOptionLiquidateHelper liquidateHelper ;
    uint maxLossRate;
    modifier onlyOwner() {
        require( msg.sender == IOwnable(diamond).owner(),"OptionLiquidateService:only owner");  
        _;
    }
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _diamond) public initializer {
        __UUPSUpgradeable_init();
        diamond = _diamond;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}


    function setLiquidateWhiteList(address _addr,bool _ok) external  onlyOwner{
        liquidateWhiteList[_addr]=_ok;
    }
    function setLiquidateHelper(address _addr) external  onlyOwner{
       liquidateHelper = IOptionLiquidateHelper(_addr);
    }
    function setETHLiquidateDecimals(uint _decimals) external  onlyOwner{
       ethLiquidateDecimals = _decimals;
    }
    function setMaxLossRate(uint _rate) external  onlyOwner{
       maxLossRate = _rate;
    }

    
    //-------liquidate--------
    function liquidateOption(
        IOptionService.LiquidateParams calldata _params,
        address _sender
    ) external payable  nonReentrant returns (IOptionService.LiquidateResult memory result){
        IOptionFacet optionFacet = IOptionFacet(diamond);
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        if (IOptionFacet.OrderType.Call == _params._orderType) {
            IOptionFacet.CallOrder memory order = IOptionFacet(diamond).getCallOrder(_params._orderID);          
            require( order.holder != address(0), "OptionLiquidateService:optionOrder not exist" );  
            LiquidateOrder memory optionOrder=LiquidateOrder({
                        holder:order.holder,
                        liquidateMode:order.liquidateMode,
                        writer:order.writer,
                        lockAssetType:order.lockAssetType,
                        recipient:order.recipient,
                        lockAsset:order.lockAsset,
                        strikeAsset:order.strikeAsset,
                        lockAmount:order.lockAmount,
                        strikeAmount:order.strikeAmount,
                        expirationDate:order.expirationDate,
                        underlyingNftID:order.underlyingNftID,
                        quantity:order.quantity
            });
            if ( optionOrder.liquidateMode == (IOptionFacet.LiquidateMode.PhysicalDelivery) ) {  
                require(_params._type != IOptionService.LiquidateType.ProfitTaking, "OptionLiquidateService:Unauthorized method of option settlement, type Error");      
            }      
            vaultFacet.setVaultLock(optionOrder.holder, false);
            address owner = IVault(optionOrder.holder).owner();
           
            if ( _sender == owner ||  (IPlatformFacet(diamond).getIsVault(_sender) &&  IOwnable(_sender).owner() == owner) ) {
                 // amo option
                require(block.timestamp >= order.lockDate,"Not yet reached lockDate");
                 result=handleliquidateOrder(_params,optionOrder,_sender);
            } else if (block.timestamp >= optionOrder.expirationDate) {
                // euo option
                 result=handleliquidateOrder(_params,optionOrder,_sender);
            } else {
                revert("OptionLiquidateService:liquidate time not yet");
            }
            optionFacet.deleteCallOrder(_params._orderID);
        } else {
            IOptionFacet.PutOrder memory order = IOptionFacet(diamond).getPutOrder(_params._orderID); 
            require(order.holder != address(0),"OptionLiquidateService:optionOrder not exist");    
            LiquidateOrder memory optionOrder=LiquidateOrder({
                         holder:order.holder,
                         liquidateMode:order.liquidateMode,
                         writer:order.writer,
                         lockAssetType:order.lockAssetType,
                         recipient:order.recipient,
                         lockAsset:order.lockAsset,
                         strikeAsset:order.strikeAsset,
                         lockAmount:order.lockAmount,
                         strikeAmount:order.strikeAmount,
                         expirationDate:order.expirationDate,
                         underlyingNftID:order.underlyingNftID,
                        quantity:order.quantity
            });
            if ( optionOrder.liquidateMode == (IOptionFacet.LiquidateMode.PhysicalDelivery)  ) {     
                require(_params._type != IOptionService.LiquidateType.ProfitTaking, "OptionLiquidateService:Unauthorized method of option LiquidateType:ProfitTaking type Error" );     
            }
            if ( optionOrder.liquidateMode == (IOptionFacet.LiquidateMode.ProfitSettlement) ) {     
                require(_params._type != IOptionService.LiquidateType.Exercising, "OptionLiquidateService:Unauthorized method of option LiquidateType:Exercising  type Error" );     
            }
            vaultFacet.setVaultLock(optionOrder.holder, false);
            address owner = IVault(optionOrder.holder).owner();
            if ( _sender == owner || (IPlatformFacet(diamond).getIsVault(_sender) &&  IOwnable(_sender).owner() == owner) ) {  
                // amo option
                require(block.timestamp >= order.lockDate,"Not yet reached lockDate");
                 result=handleliquidateOrder(_params,optionOrder,_sender);
            } else if (block.timestamp > optionOrder.expirationDate) {
                // euo option
                require(_params._type != IOptionService.LiquidateType.Exercising, "OptionLiquidateService::Unauthorized method of option LiquidateType: Exercising " );     
                 result=handleliquidateOrder(_params,optionOrder,_sender);
            } else {
                revert("OptionLiquidateService:liquidate time not yet");
            }
            optionFacet.deletePutOrder(_params._orderID);
        }
        return result;
    }

    function handleliquidateOrder(
        IOptionService.LiquidateParams calldata _params,
        LiquidateOrder memory optionOrder,
        address _sender
    ) internal returns(IOptionService.LiquidateResult memory result){
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        address eth = platformFacet.getEth();
        address recipientAddr;
        IOptionFacetV2.OptionExtra memory  extraData = IOptionFacetV2(diamond).getOptionExtraData(_params._orderID);
         if (extraData.liquidationToEOA){
            recipientAddr = IOwnable(optionOrder.recipient).owner();
         }
        if (_params._type == IOptionService.LiquidateType.Exercising) {
            uint256 strikeAmount=getParts(optionOrder.quantity, optionOrder.strikeAmount);
            if(optionOrder.strikeAsset == eth ){
                IVault(optionOrder.recipient).invokeTransferEth(optionOrder.writer,strikeAmount);                 
            }else{
                IVault(optionOrder.recipient).invokeTransfer(optionOrder.strikeAsset, optionOrder.writer,strikeAmount);     
            }
            updatePosition(optionOrder.recipient, optionOrder.strikeAsset, 0);
            updatePosition(optionOrder.writer, optionOrder.strikeAsset, 0);
            if(optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Original){
                IVault(optionOrder.holder).invokeTransferEth(recipientAddr, getParts(optionOrder.quantity, optionOrder.lockAmount));
            }else if(optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Token){
                uint256 balance=IERC20(optionOrder.lockAsset).balanceOf(optionOrder.holder);
                IVault(optionOrder.holder).invokeTransfer(optionOrder.lockAsset,recipientAddr,balance);
            }else if(optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Nft){
                IVault(optionOrder.holder).invokeTransferNft(optionOrder.lockAsset,recipientAddr,optionOrder.underlyingNftID);
            }else{
                revert("OptionLiquidateService:liquidateCall UnderlyingAssetType error");
            }
            updatePosition(optionOrder.holder, optionOrder.lockAsset, 0);       
        } else if (_params._type == IOptionService.LiquidateType.NotExercising) {
            //unlock
            if( optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Original){
                    IVault(optionOrder.holder).invokeTransferEth(optionOrder.writer, getParts(optionOrder.quantity, optionOrder.lockAmount));           
            }else if ( optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Token) { 
                   uint256 balance = IERC20(optionOrder.lockAsset).balanceOf(optionOrder.holder);             
                    IVault(optionOrder.holder).invokeTransfer(
                        optionOrder.lockAsset,
                        optionOrder.writer,
                        balance
                    );
            } else if (optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Nft ) {
                IVault(optionOrder.holder).invokeTransferNft(
                    optionOrder.lockAsset,
                    optionOrder.writer,
                    optionOrder.underlyingNftID
                );
            } else {
                revert("OptionLiquidateService:liquidateCall lockAssetType error");
            }
            updatePosition(optionOrder.holder, optionOrder.lockAsset, 0);
            updatePosition(optionOrder.writer, optionOrder.lockAsset, 0);
        } else if (_params._type ==IOptionService.LiquidateType.ProfitTaking) {
            if ( optionOrder.lockAssetType != IOptionFacet.UnderlyingAssetType.Nft ) {  
                result = getEarningsAmount(
                    GetEarningsAmount({
                        lockAsset:optionOrder.lockAsset,
                        lockAmount:getParts(optionOrder.quantity, optionOrder.lockAmount),
                        strikeAsset:optionOrder.strikeAsset,
                        strikeAmount:getParts(optionOrder.quantity, optionOrder.strikeAmount),
                        expirationDate:optionOrder.expirationDate,
                        index: _params._index,
                        lockAssetPriceData: _params.lockAssetPricData,
                        strikeAssetPriceData: _params.strikeAssetPricData,
                        extraData: extraData,
                        orderType:_params._orderType,
                        sender: _sender
                    })
                );
                // maxLoss
                result.amount = getMaxLossEarn(getParts(optionOrder.quantity,optionOrder.lockAmount), result.amount);
                if (optionOrder.lockAsset == eth) {
                    IVault(optionOrder.holder).invokeTransferEth(recipientAddr,result.amount);
                    IVault(optionOrder.holder).invokeTransferEth(optionOrder.writer, getParts(optionOrder.quantity, optionOrder.lockAmount) -result. amount);
                } else {
                    IVault(optionOrder.holder).invokeTransfer( optionOrder.lockAsset, optionOrder.writer, 
                                    getParts(optionOrder.quantity, optionOrder.lockAmount) - result.amount );       
                    IVault(optionOrder.holder).invokeTransfer( optionOrder.lockAsset, recipientAddr,result.amount );          
                }
            }else{
                revert("OptionLiquidateService:liquidateCall LiquidateType error");
            }
            updatePosition(optionOrder.holder, optionOrder.lockAsset, 0);
            updatePosition(optionOrder.writer, optionOrder.lockAsset, 0);
            updatePosition(optionOrder.recipient, optionOrder.lockAsset, 0);
        }
       return result;
    }

    function getETHdecimals(address _weth)public  view returns(uint ){
        if (ethLiquidateDecimals!=0){
            return ethLiquidateDecimals;
        }
        return  IERC20(_weth).decimals();
    }
    function  getMaxLossEarn(uint lockAmount, uint earnAmount)internal view returns(uint earn){
        if (lockAmount*maxLossRate / 1 ether <= earnAmount ){
            return  lockAmount*maxLossRate;
        }
        return earnAmount;
    }
    function getEarningsAmount(
        GetEarningsAmount memory _data
    ) public returns (IOptionService.LiquidateResult memory result) { 
        address eth=IPlatformFacet(diamond).getEth();
        address weth=IPlatformFacet(diamond).getWeth();
        uint256 lockAssetPrice;
        uint256 strikeAssetPrice;
        uint256 earn;
        if (_data.extraData.optionSourceType>0){
            require(liquidateWhiteList[_data.sender],"OptionLiquidateService:optionSourceType not support");
        }
        if (liquidateWhiteList[_data.sender]){
            (lockAssetPrice,strikeAssetPrice) = liquidateHelper.whiteListLiquidatePrice(_data);
        }else{
            (lockAssetPrice,strikeAssetPrice) = liquidateHelper.verifyLiquidatePrice(_data);
        }
        // uint256 lockAssetPrice = priceOracle.getHistoryPrice(_data.lockAsset,_data.index,_data.data[0]);        
        // uint256 strikeAssetPrice = priceOracle.getHistoryPrice(_data.strikeAsset,_data.index,_data.expirationDate,_data.data[0]);        
        uint lockAssetDecimal = uint(_data.lockAsset == eth ? getETHdecimals(weth):IERC20(_data.lockAsset).decimals());
        uint strikeAssetDecimal =   uint(_data.strikeAsset == eth ? getETHdecimals(weth):IERC20(_data.strikeAsset).decimals());
        uint reversePrice =  1 ether * 1 ether / (lockAssetPrice/strikeAssetPrice);
        uint nowAmount = (_data.lockAmount * lockAssetPrice * 10 ** strikeAssetDecimal  )  / 10 ** lockAssetDecimal / 1 ether;
        earn = _data.strikeAmount >= nowAmount ? 0:((nowAmount-_data.strikeAmount) * reversePrice *  10 ** lockAssetDecimal) / 10 ** strikeAssetDecimal /1 ether;
        result.amount=earn;
        result.lockAssetPrice=lockAssetPrice;
        result.strikeAssetPrice=strikeAssetPrice;
        return result;
    }
    function getParts(uint256 quantity ,uint256 strikeAmount)  public pure returns(uint256){
        return quantity*strikeAmount/ 1 ether;
    }

}
