// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../lib/ModuleBase.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {Invoke} from "../lib/Invoke.sol";
import {IOptionService} from "../interfaces/internal/IOptionService.sol";
import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
import {INonfungiblePositionManager} from "../interfaces/external/INonfungiblePositionManager.sol";
import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";

contract OptionService is  ModuleBase,IOptionService, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    using Invoke for IVault;
    IPriceOracle public priceOracle;
    modifier onlyOwner() {
        require( msg.sender == IOwnable(diamond).owner(),"OptionService:only owner");  
        _;
    }
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _diamond,address _priceOracle) public initializer {
        __UUPSUpgradeable_init();
        diamond = _diamond;
        priceOracle=IPriceOracle(_priceOracle);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setPriceOracle(IPriceOracle _priceOracle) external  onlyOwner{
        priceOracle=_priceOracle;
    }

    //---base call+put---
    function createPutOrder(
        IOptionFacet.PutOrder memory _putOrder
    ) external  onlyModule{
        IOptionFacet optionFacet = IOptionFacet(diamond);
        optionFacet.setOrderId();
        uint64 _orderId=optionFacet.getOrderId();
        VerifyOrder memory _verifyOrder = VerifyOrder({
            holder: _putOrder.holder,
            liquidateMode: _putOrder.liquidateMode,
            writer: _putOrder.writer,
            lockAssetType: _putOrder.lockAssetType,
            recipient: _putOrder.recipient,
            lockAsset: _putOrder.lockAsset,
            strikeAsset: _putOrder.strikeAsset,
            lockAmount: _putOrder.lockAmount,
            strikeAmount: _putOrder.strikeAmount,
            expirationDate: _putOrder.expirationDate,
            lockDate: _putOrder.lockDate,
            underlyingNftID: _putOrder.underlyingNftID,
            writerType: 2,
            holderType: 3,
            quantity:_putOrder.quantity
        });
        verifyOrder(_verifyOrder);
        optionFacet.addPutOrder(_orderId, _putOrder);
        updatePosition(_putOrder.holder, _putOrder.lockAsset, 0);
        updatePosition(_putOrder.writer, _putOrder.lockAsset, 0);
    }

    function createCallOrder(
        IOptionFacet.CallOrder memory _callOrder
    ) external  onlyModule{
        IOptionFacet optionFacet = IOptionFacet(diamond);
        optionFacet.setOrderId();
        uint64 _orderId=optionFacet.getOrderId();
        VerifyOrder memory _verifyOrder = VerifyOrder({
            holder: _callOrder.holder,
            liquidateMode: _callOrder.liquidateMode,
            writer: _callOrder.writer,
            lockAssetType: _callOrder.lockAssetType,
            recipient: _callOrder.recipient,
            lockAsset: _callOrder.lockAsset,
            strikeAsset: _callOrder.strikeAsset,
            lockAmount: _callOrder.lockAmount,
            strikeAmount: _callOrder.strikeAmount,
            expirationDate: _callOrder.expirationDate,
            lockDate:_callOrder.lockDate,
            underlyingNftID: _callOrder.underlyingNftID,
            writerType: 6,
            holderType: 7,
            quantity: _callOrder.quantity
        });
        verifyOrder(_verifyOrder);  
        optionFacet.addCallOrder(_orderId, _callOrder);
        updatePosition(_callOrder.holder, _callOrder.lockAsset, 0);
        updatePosition(_callOrder.writer, _callOrder.lockAsset, 0);
    }

    function verifyOrder(VerifyOrder memory _verifyOrder) internal {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        IOptionFacet optionFacet = IOptionFacet(diamond);

        require(
           platformFacet.getIsVault(_verifyOrder.recipient) && IOwnable(_verifyOrder.holder).owner()==IOwnable(_verifyOrder.recipient).owner(),
            "OptionService:recipient error"
        );

        require(
            platformFacet.getTokenType(_verifyOrder.lockAsset) != 0,
            "OptionService:lockAsset error"
        );
        require(
            platformFacet.getTokenType(_verifyOrder.strikeAsset) != 0,
            "OptionService:strikeAsset error"
        );
        require(
            !vaultFacet.getVaultLock(_verifyOrder.holder),
            "OptionService:holder is locked"
        );
        require(
            !vaultFacet.getVaultLock(_verifyOrder.writer),
            "OptionService:writer is locked"
        );
        require(
            vaultFacet.getVaultType(_verifyOrder.holder) ==
                _verifyOrder.holderType,
            "OptionService:holder vaultType error"
        );
        // require(
        //     vaultFacet.getVaultType(_verifyOrder.writer) ==
        //         _verifyOrder.writerType,
        //     "OptionService:writer vaultType error"
        // );
        require(
            _verifyOrder.expirationDate > block.timestamp,
            "OptionService:invalid expirationDate"
        );
       require(
            _verifyOrder.lockDate  > block.timestamp &&  _verifyOrder.expirationDate > _verifyOrder.lockDate,
            "OptionService:invalid lockDate"
        );
        require(
            _verifyOrder.writer != _verifyOrder.holder,
            "OptionService:holder error"
        );
       

        if (
            _verifyOrder.lockAssetType ==
            IOptionFacet.UnderlyingAssetType.Original
        ) {
            require(
                _verifyOrder.quantity == _verifyOrder.lockAmount,
                "OptionService:quantity not equal lockAmount/decimals"
            );
            require(
                _verifyOrder.writer.balance >= _verifyOrder.lockAmount,
                "OptionService:lockAmount not enough"
            );

            IVault(_verifyOrder.writer).invokeTransferEth(
                _verifyOrder.holder,
                _verifyOrder.lockAmount
            );
        } else if (
            _verifyOrder.lockAssetType ==
            IOptionFacet.UnderlyingAssetType.Token
        ) {
              require(
                _verifyOrder.quantity ==(1 ether * _verifyOrder.lockAmount) / (10 ** IERC20(_verifyOrder.lockAsset).decimals()),
                "OptionService:quantity not equal lockAmount/decimals"
            );
            require(
                IERC20(_verifyOrder.lockAsset).balanceOf(
                    _verifyOrder.writer
                ) >= _verifyOrder.lockAmount,
                "OptionService:lockAmount not enough"
            );

            IVault(_verifyOrder.writer).invokeTransfer(
                _verifyOrder.lockAsset,
                _verifyOrder.holder,
                _verifyOrder.lockAmount
            );
        } else if (
            _verifyOrder.lockAssetType ==
            IOptionFacet.UnderlyingAssetType.Nft
        ) {
            if (
                optionFacet.getNftType(_verifyOrder.lockAsset) ==
                IOptionFacet.CollateralNftType.UniswapV3
            ) {
                (
                    ,
                    ,
                    address token0,
                    address token1,
                    ,
                    ,
                    ,
                    uint128 liquidity,
                    ,
                    ,
                    ,

                ) = INonfungiblePositionManager(_verifyOrder.lockAsset)
                        .positions(_verifyOrder.underlyingNftID);
                require(
                    platformFacet.getTokenType(token0) != 0 &&
                        platformFacet.getTokenType(token1) != 0,
                    "OptionService:nft assets error"
                );
                require(
                    uint256(liquidity) >= _verifyOrder.lockAmount,
                    "OptionService:lockAmount not enough"
                );
                IVault(_verifyOrder.writer).invokeTransferNft(
                    _verifyOrder.lockAsset,
                    _verifyOrder.holder,
                    _verifyOrder.underlyingNftID
                );
            } else {
                revert("OptionService:invalid Nft");
            }
        } else {
            revert("OptionService:lockAssetType error");
        }
        setFuncBlackList(_verifyOrder.writer, true);
        setFuncWhiteList(_verifyOrder.holder, true);
        vaultFacet.setVaultLock(_verifyOrder.holder, true);
    }

    function setFuncBlackList(address _blacker, bool _type) internal {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        vaultFacet.setFuncBlackList(
            _blacker,
            bytes4(keccak256("setVaultType(address,uint256)")),
            _type
        );
    }

    function setFuncWhiteList(address _whiter, bool _type) internal {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        vaultFacet.setFuncWhiteList(
            _whiter,
            bytes4(
                keccak256(
                    "replacementLiquidity(address,uint8,uint24,int24,int24)"
                )
            ),
            _type
        );
        vaultFacet.setFuncWhiteList(
            _whiter,
            bytes4(
                keccak256(
                    "liquidateOption(uint8,uint64,uint8,uint256,uint256)"
                )
            ),
            _type
        );
    }
    //-------liquidate--------
    function liquidateOption(
        IOptionFacet.OrderType _orderType,
        uint64 _orderID,
        LiquidateType _type,
        uint256 _incomeAmount,
        uint256 _slippage
    ) external payable nonReentrant{
        IOptionFacet optionFacet = IOptionFacet(diamond);
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        if (IOptionFacet.OrderType.Call == _orderType) {
            IOptionFacet.CallOrder memory order = IOptionFacet(diamond).getCallOrder(_orderID);          
            require( order.holder != address(0), "OptionService:optionOrder not exist" );  
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
                require( _type != LiquidateType.ProfitTaking, "OptionService:Unauthorized method of option settlement, type Error");      
            }      
            vaultFacet.setVaultLock(optionOrder.holder, false);
            address owner = IVault(optionOrder.holder).owner();
            if ( msg.sender == owner ||   (IPlatformFacet(diamond).getIsVault(msg.sender) &&  IOwnable(msg.sender).owner() == owner) ) {
                liquidateOrder(optionOrder, _type, _incomeAmount, _slippage);
            } else if (block.timestamp > optionOrder.expirationDate) {
                liquidateOrder( optionOrder, _type,_incomeAmount, _slippage );     
            } else {
                revert("OptionService:liquidate time not yet");
            }
            optionFacet.deleteCallOrder(_orderID);
        } else {
            IOptionFacet.PutOrder memory order = IOptionFacet(diamond).getPutOrder(_orderID); 
            require(order.holder != address(0),"OptionService:optionOrder not exist");    
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
                require(_type != LiquidateType.ProfitTaking, "OptionService:Unauthorized method of option settlement, type Error" );     
            }
            vaultFacet.setVaultLock(optionOrder.holder, false);
            address owner = IVault(optionOrder.holder).owner();
            if ( msg.sender == owner || (IPlatformFacet(diamond).getIsVault(msg.sender) &&  IOwnable(msg.sender).owner() == owner) ) {  
                liquidateOrder(optionOrder, _type, _incomeAmount, _slippage);
            } else if (block.timestamp > optionOrder.expirationDate) {
                liquidateOrder(
                    optionOrder,
                    _type,
                    _incomeAmount,
                    _slippage
                );
            } else {
                revert("OptionService:liquidate time not yet");
            }
            optionFacet.deletePutOrder(_orderID);
        }
        emit LiquidateOption(
            _orderType,
            _orderID,
            _type,
            _incomeAmount,
            _slippage
        );
    }
    function liquidateOrder(
        LiquidateOrder memory optionOrder,
        LiquidateType _type,
        uint256 _incomeAmount,
        uint256 _slippage
    ) internal {
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        address eth = platformFacet.getEth();
        if (_type == LiquidateType.Exercising) {
            uint256 strikeAmount=getParts(optionOrder.quantity, optionOrder.strikeAmount);
             if(optionOrder.strikeAsset == eth ){
                 IVault(optionOrder.recipient).invokeTransferEth(optionOrder.writer,strikeAmount);                 
             }else{
                 IVault(optionOrder.recipient).invokeTransfer(optionOrder.strikeAsset, optionOrder.writer,strikeAmount);     
             }
             updatePosition(optionOrder.recipient, optionOrder.strikeAsset, 0);
             updatePosition(optionOrder.writer, optionOrder.strikeAsset, 0);

             if(optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Original){
                IVault(optionOrder.holder).invokeTransferEth(optionOrder.recipient,optionOrder.lockAmount);
             }else if(optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Token){
                 uint256 balance=IERC20(optionOrder.lockAsset).balanceOf(optionOrder.holder);
                 IVault(optionOrder.holder).invokeTransfer(optionOrder.lockAsset,optionOrder.recipient,balance);
             }else if(optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Nft){
                 IVault(optionOrder.holder).invokeTransferNft(optionOrder.lockAsset,optionOrder.recipient,optionOrder.underlyingNftID);
             }else{
                revert("OptionService:liquidateCall UnderlyingAssetType error");
             }
             updatePosition(optionOrder.recipient, optionOrder.lockAsset, 0);
             updatePosition(optionOrder.holder, optionOrder.lockAsset, 0);       
        }   else if (_type == LiquidateType.NotExercising) {
            //unlock
            if( optionOrder.lockAssetType == IOptionFacet.UnderlyingAssetType.Original){
                    IVault(optionOrder.holder).invokeTransferEth(optionOrder.writer, optionOrder.lockAmount);           
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
                revert("OptionService:liquidateCall lockAssetType error");
            }
            updatePosition(optionOrder.holder, optionOrder.lockAsset, 0);
            updatePosition(optionOrder.writer, optionOrder.lockAsset, 0);
        } else if (_type ==LiquidateType.ProfitTaking) {
            if ( optionOrder.lockAssetType != IOptionFacet.UnderlyingAssetType.Nft ) {   
                uint amount = getEarningsAmount(
                    optionOrder.lockAsset,
                    optionOrder.lockAmount,
                    optionOrder.strikeAsset,
                    optionOrder.strikeAmount,
                    optionOrder.quantity
                );
                // require( amount > 0,"OptionService:Call getEarningsAmount too low");
                validSlippage(amount, _incomeAmount, _slippage, _slippage);
                if (optionOrder.lockAsset == eth) {
                    IVault(optionOrder.holder).invokeTransferEth(optionOrder.writer, optionOrder.lockAmount - amount);
                    IVault(optionOrder.holder).invokeTransferEth(optionOrder.recipient,amount);
   
                } else {
                    uint256 balance = IERC20(optionOrder.lockAsset).balanceOf(optionOrder.holder);        
                    IVault(optionOrder.holder).invokeTransfer( optionOrder.lockAsset, optionOrder.writer, balance - amount );
                    IVault(optionOrder.holder).invokeTransfer( optionOrder.lockAsset, optionOrder.recipient,amount );          
                }
            } else {
                revert("OptionService:liquidateCall LiquidateType error");
            }
            updatePosition(optionOrder.holder, optionOrder.lockAsset, 0);
            updatePosition(optionOrder.writer, optionOrder.lockAsset, 0);
            updatePosition(optionOrder.recipient, optionOrder.lockAsset, 0);
        }
    }

    function validSlippage(
        uint amountA,
        uint amountB,
        uint holderSlippage,
        uint writerSlippage
    ) public pure returns (bool) {
        uint slippage = holderSlippage < writerSlippage
            ? holderSlippage
            : writerSlippage;
        require(
            amountA <= (amountB * (1 ether + slippage)) / 1 ether,
            "OptionService: amountA < amountB"
        );
        require(
            amountA >= (amountB * (1 ether - slippage)) / 1 ether,
            "OptionService: amountA > amountB"
        );
        return true;
    }

    function getEarningsAmount(
        address lockAsset, // ETH
        uint256 lockAmount, // 1
        address strikeAsset, // USDC
        uint256 strikeNotionalAmount,
        uint256 quantity
    ) public view returns (uint) { 
        address eth=IPlatformFacet(diamond).getEth();
        address weth=IPlatformFacet(diamond).getWeth();
        uint price = priceOracle.getPrice(lockAsset == eth ? weth : lockAsset, strikeAsset == eth ? weth : strikeAsset);        
        uint underlyingAssetDecimal = uint(IERC20(lockAsset == eth ? weth : lockAsset).decimals());
        uint strikeAssetDecimal = uint( IERC20(strikeAsset == eth ? weth : strikeAsset).decimals());    
        uint reversePrice =priceOracle.getPrice( strikeAsset == eth ? weth : strikeAsset, lockAsset == eth ? weth : lockAsset);     
        uint nowAmount = (lockAmount * price * 10 ** strikeAssetDecimal) / 10 ** underlyingAssetDecimal / 1 ether;   
        //Calculate the current value of the collateral
        uint256  currentStrikeAmount= getParts(quantity, strikeNotionalAmount);
        return currentStrikeAmount >= nowAmount ? 0:((nowAmount-currentStrikeAmount) * reversePrice *  10 ** underlyingAssetDecimal) / 10 ** strikeAssetDecimal /1 ether;  
    }
    function getParts(uint256 quantity ,uint256 strikeAmount)  public pure returns(uint256){
          return quantity*strikeAmount/ 1 ether;
    }
    function setTotalPremium(address _vault,address _premiumAsset,uint _premiumFee) external  onlyModule{
        uint premiumByUsd = 100*_premiumFee*priceOracle.getUSDPrice(_premiumAsset)/1 ether/10**IERC20(_premiumAsset).decimals();
        IOptionFacet(diamond).setTotalPremium(IOwnable(_vault).owner(),premiumByUsd);
    }
}
