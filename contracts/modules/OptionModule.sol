// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../lib/ModuleBase.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {Invoke} from "../lib/Invoke.sol";
import {IOptionModule} from "../interfaces/internal/IOptionModule.sol";
import {IOptionService} from "../interfaces/internal/IOptionService.sol";
import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
import {INonfungiblePositionManager} from "../interfaces/external/INonfungiblePositionManager.sol";
import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";
import {IVaultFactory} from "../interfaces/internal/IVaultFactory.sol";

contract OptionModule is ModuleBase,IOptionModule, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    using Invoke for IVault;
    IOptionService public optionService;
    mapping(bytes=>bool) signBlackList;
    mapping(address=>bool) oracleWhiteList;
    modifier onlyOwner() {
        require( msg.sender == IOwnable(diamond).owner(),"OptionModule:only owner");  
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

    function setOptionService(IOptionService _optionService) external onlyOwner{
        optionService=_optionService;
    }
    //----jvault-----
    function submitJvaultOrderSingle(SubmitJvaultOrder memory _info,bytes memory _holderSignature) external onlyVaultOrManager(_info.writer) {
        SubmitJvaultOrder memory newInfo =  SubmitJvaultOrder({
                    orderType:_info.orderType,  
                    writer:address(0),
                    lockAssetType:_info.lockAssetType,
                    holder:_info.holder, 
                    lockAsset:_info.lockAsset, 
                    underlyingNftID:_info.underlyingNftID,
                    lockAmount:_info.lockAmount,
                    underlyingAsset:_info.underlyingAsset,
                    strikeAsset:_info.strikeAsset,
                    strikeAmount:_info.strikeAmount,
                    recipient:_info.recipient,
                    liquidateMode:_info.liquidateMode,
                    expirationDate:_info.expirationDate,
                    lockDate:_info.lockDate,
                    premiumAsset:_info.premiumAsset,
                    premiumFee:_info.premiumFee,
                    quantity:_info.quantity
          });
        handleJvaultSignature(newInfo,_holderSignature,_info.holder);
        handleFee(_info);

        //create order
        if(_info.orderType==IOptionFacet.OrderType.Call){
             IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
                holder:_info.holder,
                liquidateMode:_info.liquidateMode,
                writer:_info.writer,
                lockAssetType:_info.lockAssetType,
                recipient:_info.recipient,
                lockAsset:_info.lockAsset,
                strikeAsset:_info.strikeAsset,
                lockAmount:_info.lockAmount,
                underlyingAsset:_info.underlyingAsset,
                strikeAmount:_info.strikeAmount,
                expirationDate:_info.expirationDate,
                lockDate:_info.lockDate,
                underlyingNftID:_info.underlyingNftID,
                quantity:_info.quantity
             });
            optionService.createCallOrder(callOrder);
            emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder,  _info.premiumAsset, optionService.getParts(_info.quantity, _info.premiumFee));
        }else if(_info.orderType==IOptionFacet.OrderType.Put){
            IOptionFacet.PutOrder memory putOrder= IOptionFacet.PutOrder({
                holder:_info.holder,
                liquidateMode:_info.liquidateMode,
                writer:_info.writer,
                lockAssetType:_info.lockAssetType,
                recipient:_info.recipient,
                lockAsset:_info.lockAsset,
                underlyingAsset:_info.underlyingAsset,
                strikeAsset:_info.strikeAsset,
                lockAmount:_info.lockAmount,
                strikeAmount:_info.strikeAmount,
                expirationDate:_info.expirationDate,
                lockDate:_info.lockDate,
                underlyingNftID:_info.underlyingNftID,
                quantity:_info.quantity
             });
            optionService.createPutOrder(putOrder);
            emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder,  _info.premiumAsset,optionService.getParts(_info.quantity, _info.premiumFee));
        }else{
            revert("OptionModule:orderType error");
        }
        signBlackList[_holderSignature] = true;
    }
    function handleJvaultSignature(SubmitJvaultOrder memory _info,bytes memory _signature,address _signer) internal view {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        bytes32 infoTypeHash = keccak256(
            "SubmitJvaultOrder(uint8 orderType,address writer,uint8 lockAssetType,address holder,address lockAsset,address underlyingAsset,uint256 underlyingNftID,uint256 lockAmount,address strikeAsset,uint256 strikeAmount,address recipient,uint8 liquidateMode,uint256 expirationDate,uint256 lockDate,address premiumAsset,uint256 premiumFee,uint256 quantity)"
        );

        bytes32 _hashInfo = keccak256(abi.encode(infoTypeHash,_info));
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", optionFacet.getDomain(), _hashInfo)
        );
        address signer = IVault(_signer).owner();
        address recoverAddress = ECDSA.recover(digest, _signature);
        require(recoverAddress == signer, "OptionModule:signature error");
    }
    //----option------

    function handleFee(
        SubmitJvaultOrder memory _info
    ) internal {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        IPlatformFacet platformFacet=IPlatformFacet(diamond);
        address eth= platformFacet.getEth();
        //calculate premiumFee
        uint _premiumFee= optionService.getParts(_info.quantity, _info.premiumFee);   
        //calculate platformFee
        uint256 platformFee = (_premiumFee * optionFacet.getFeeRate()) / 1 ether;           
        address feeRecipient = optionFacet.getFeeRecipient();
        require(
            !IVaultFacet(diamond).getVaultLock(_info.recipient) &&
            !IVaultFacet(diamond).getVaultLock(_info.holder),
            "OptionModule: holder vault is locked"
        );
        require(
            platformFacet.getIsVault(_info.recipient)&&platformFacet.getIsVault(_info.holder)&&
            IOwnable(_info.holder).owner()==IOwnable(_info.recipient).owner(),
            "OptionModule:recipient error"
        );
        if (_info.premiumAsset == eth) {
            IVault(_info.recipient).invokeTransferEth(_info.holder, _premiumFee);
            if (platformFee > 0 && feeRecipient != address(0)) {
                IVault(_info.holder).invokeTransferEth(feeRecipient, platformFee);
            }
            IVault(_info.holder).invokeTransferEth(_info.writer, _premiumFee - platformFee);
        } else {
            IVault(_info.recipient).invokeTransfer(_info.premiumAsset, _info.holder, _premiumFee);
            if (platformFee > 0 && feeRecipient != address(0)) {
                IVault(_info.holder).invokeTransfer( _info.premiumAsset,feeRecipient,platformFee);         
            }
            IVault(_info.holder).invokeTransfer(_info.premiumAsset, _info.writer, _premiumFee - platformFee );     
        }
    }




}