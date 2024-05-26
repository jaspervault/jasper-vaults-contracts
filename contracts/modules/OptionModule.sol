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

contract OptionModule is ModuleBase,IOptionModule, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    using Invoke for IVault;
    IOptionService public optionService;
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
    function submitJvaultOrder(SubmitJvaultOrder memory _info,bytes memory _writerSignature,bytes memory _holderSignature) external {
         handleJvaultSignature(_info,_writerSignature,_info.writer);
         SubmitJvaultOrder memory newInfo =  SubmitJvaultOrder({
                    orderType:_info.orderType,  
                    writer:address(0),
                    underlyingAssetType:_info.underlyingAssetType,
                    holder:_info.holder, 
                    underlyingAsset:_info.underlyingAsset, 
                    underlyingNftID:_info.underlyingNftID,
                    underlyingAmount:_info.underlyingAmount,
                    strikeAsset:_info.strikeAsset,
                    strikeAmount:_info.strikeAmount,
                    recipient:_info.recipient,
                    liquidateMode:_info.liquidateMode,
                    expirationDate:_info.expirationDate,
                    premiumAsset:_info.premiumAsset,
                    premiumFee:_info.premiumFee
          });
         handleJvaultSignature(newInfo,_holderSignature,_info.holder);
         handleFee(
                _info.holder,
                _info.writer,
                _info.premiumAsset,
                _info.premiumFee,
                _info.underlyingAsset,
                _info.underlyingAmount
         );
        //create order
        if(_info.orderType==IOptionFacet.OrderType.Call){
             IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
                         holder:_info.holder,
                         liquidateMode:_info.liquidateMode,
                         writer:_info.writer,
                         underlyingAssetType:_info.underlyingAssetType,
                         recipient:_info.recipient,
                         underlyingAsset:_info.underlyingAsset,
                         strikeAsset:_info.strikeAsset,
                         underlyingAmount:_info.underlyingAmount,
                         strikeAmount:_info.strikeAmount,
                         expirationDate:_info.expirationDate,
                         underlyingNftID:_info.underlyingNftID
             });
             optionService.createCallOrder(callOrder);
             emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder,  _info.premiumAsset,  _info.premiumFee);
        }else if(_info.orderType==IOptionFacet.OrderType.Put){
            IOptionFacet.PutOrder memory putOrder= IOptionFacet.PutOrder({
                         holder:_info.holder,
                         liquidateMode:_info.liquidateMode,
                         writer:_info.writer,
                         underlyingAssetType:_info.underlyingAssetType,
                         recipient:_info.recipient,
                         underlyingAsset:_info.underlyingAsset,
                         strikeAsset:_info.strikeAsset,
                         underlyingAmount:_info.underlyingAmount,
                         strikeAmount:_info.strikeAmount,
                         expirationDate:_info.expirationDate,
                         underlyingNftID:_info.underlyingNftID
             });
             optionService.createPutOrder(putOrder);
             emit OptionPremiun(IOptionFacet.OrderType.Put ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder,  _info.premiumAsset,  _info.premiumFee);
        }else{
            revert("OptionModule:orderType error");
        }
    }
        //----jvault-----
    function submitJvaultOrderSingle(SubmitJvaultOrder memory _info,bytes memory _holderSignature) external onlyVaultManager(_info.writer) {
        SubmitJvaultOrder memory newInfo =  SubmitJvaultOrder({
                    orderType:_info.orderType,  
                    writer:address(0),
                    underlyingAssetType:_info.underlyingAssetType,
                    holder:_info.holder, 
                    underlyingAsset:_info.underlyingAsset, 
                    underlyingNftID:_info.underlyingNftID,
                    underlyingAmount:_info.underlyingAmount,
                    strikeAsset:_info.strikeAsset,
                    strikeAmount:_info.strikeAmount,
                    recipient:_info.recipient,
                    liquidateMode:_info.liquidateMode,
                    expirationDate:_info.expirationDate,
                    premiumAsset:_info.premiumAsset,
                    premiumFee:_info.premiumFee
          });
         handleJvaultSignature(newInfo,_holderSignature,_info.holder);
         handleFee(
                _info.holder,
                _info.writer,
                _info.premiumAsset,
                _info.premiumFee,
                _info.underlyingAsset,
                _info.underlyingAmount
         );
        //create order
        if(_info.orderType==IOptionFacet.OrderType.Call){
             IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
                         holder:_info.holder,
                         liquidateMode:_info.liquidateMode,
                         writer:_info.writer,
                         underlyingAssetType:_info.underlyingAssetType,
                         recipient:_info.recipient,
                         underlyingAsset:_info.underlyingAsset,
                         strikeAsset:_info.strikeAsset,
                         underlyingAmount:_info.underlyingAmount,
                         strikeAmount:_info.strikeAmount,
                         expirationDate:_info.expirationDate,
                         underlyingNftID:_info.underlyingNftID
             });
             optionService.createCallOrder(callOrder);
                emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder,  _info.premiumAsset,  _info.premiumFee);

        }else if(_info.orderType==IOptionFacet.OrderType.Put){
            IOptionFacet.PutOrder memory putOrder= IOptionFacet.PutOrder({
                         holder:_info.holder,
                         liquidateMode:_info.liquidateMode,
                         writer:_info.writer,
                         underlyingAssetType:_info.underlyingAssetType,
                         recipient:_info.recipient,
                         underlyingAsset:_info.underlyingAsset,
                         strikeAsset:_info.strikeAsset,
                         underlyingAmount:_info.underlyingAmount,
                         strikeAmount:_info.strikeAmount,
                         expirationDate:_info.expirationDate,
                         underlyingNftID:_info.underlyingNftID
             });
             optionService.createPutOrder(putOrder);
            emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder,  _info.premiumAsset,  _info.premiumFee);

        }else{
            revert("OptionModule:orderType error");
        }
    }
    function handleJvaultSignature(SubmitJvaultOrder memory _info,bytes memory _signature,address _signer) internal view {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        bytes32 infoTypeHash = keccak256(
            "SubmitJvaultOrder(uint8 orderType,address writer,uint8 underlyingAssetType,address holder,address underlyingAsset,uint256 underlyingNftID,uint256 underlyingAmount,address strikeAsset,uint256 strikeAmount,address recipient,uint8 liquidateMode,uint256 expirationDate,address premiumAsset,uint256 premiumFee)"
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
    //----signature-----
    function setSigatureLock(
        address _vault,
        IOptionFacet.OrderType _orderType,
        address _underlyingAsset,
        uint256 _timestamp
    ) external onlyVaultManager(_vault) {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        uint256 timestamp=optionFacet.getSigatureLock(_vault,_orderType,_underlyingAsset);
        require(_timestamp>timestamp+2,"OptionModule:timestamp invaild");
        optionFacet.setSigatureLock(_vault,_orderType,_underlyingAsset,_timestamp-1);
        optionFacet.setUnderlyTotal(_vault,_orderType,_underlyingAsset,0);
    }

    //-----submit Order-----
    function submitOptionOrder(SubmitOrder memory _info,bytes memory _writerSignature) external  onlyVaultOrManager(_info.holder){   
        require(_info.strikeSelect<=_info.signature.strikeAssets.length,"OptionModule:strikeSelect error");
        require(_info.premiumSelect<=_info.signature.premiumAssets.length,"OptionModule:premiumSelect error");
        require(_info.liquidateSelect<=_info.signature.liquidateModes.length,"OptionModule:liquidateSelect error");
        //verify signature
        handleSignature(_info.signature, _info.writer, _writerSignature);
        checkTotalAndTimestamp(_info.signature.orderType,_info.signature,_info.writer,_info.underlyingAmount);
        //transfer fee
        handleFee(
                _info.holder,
                _info.writer,
                _info.signature.premiumAssets[_info.premiumSelect],
                _info.signature.premiumFees[_info.premiumSelect],
                _info.signature.underlyingAsset,
                _info.underlyingAmount
        );
        //create order
        if(_info.signature.orderType==IOptionFacet.OrderType.Call){
             IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
                         holder:_info.holder,
                         liquidateMode:_info.signature.liquidateModes[_info.liquidateSelect],
                         writer:_info.writer,
                         underlyingAssetType:_info.signature.underlyingAssetType,
                         recipient:_info.recipient,
                         underlyingAsset:_info.signature.underlyingAsset,
                         strikeAsset:_info.signature.strikeAssets[_info.strikeSelect],
                         underlyingAmount:_info.underlyingAmount,
                         strikeAmount:_info.signature.strikeAmounts[_info.strikeSelect],
                         expirationDate:_info.signature.expirationDate,
                         underlyingNftID:_info.signature.underlyingNftID
             });
             optionService.createCallOrder(callOrder);
            emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder, _info.signature.premiumAssets[_info.premiumSelect] ,  _info.signature.premiumFees[_info.premiumSelect]);

        }else if(_info.signature.orderType==IOptionFacet.OrderType.Put){
            IOptionFacet.PutOrder memory putOrder= IOptionFacet.PutOrder({
                         holder:_info.holder,
                         liquidateMode:_info.signature.liquidateModes[_info.liquidateSelect],
                         writer:_info.writer,
                         underlyingAssetType:_info.signature.underlyingAssetType,
                         recipient:_info.recipient,
                         underlyingAsset:_info.signature.underlyingAsset,
                         strikeAsset:_info.signature.strikeAssets[_info.strikeSelect],
                         underlyingAmount:_info.underlyingAmount,
                         strikeAmount:_info.signature.strikeAmounts[_info.strikeSelect],
                         expirationDate:_info.signature.expirationDate,
                         underlyingNftID:_info.signature.underlyingNftID
             });
             optionService.createPutOrder(putOrder);
            emit OptionPremiun(IOptionFacet.OrderType.Put ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder, _info.signature.premiumAssets[_info.premiumSelect] ,  _info.signature.premiumFees[_info.premiumSelect]);

        }else{
            revert("OptionModule:orderType error");
        }
    }

    function handleFee(
        address _from,
        address _to,
        address _premiumAsset,
        uint256 _premiumFee,
        address _underlyingAsset,
        uint256 _underlyingAmount
    ) internal {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        IPlatformFacet platformFacet=IPlatformFacet(diamond);
        address eth= platformFacet.getEth();
        //calculate premiumFee
        _premiumFee= optionService.getParts(_underlyingAsset,_underlyingAmount, _premiumFee);   
        //calculate platformFee
        uint256 platformFee = (_premiumFee * optionFacet.getFeeRate()) / 1 ether;
           
        address feeRecipient = optionFacet.getFeeRecipient();
        if (_premiumAsset == eth) {
            if (platformFee > 0 && feeRecipient != address(0)) {
                IVault(_from).invokeTransferEth(feeRecipient, platformFee);
            }
            IVault(_from).invokeTransferEth(_to, _premiumFee - platformFee);
        } else {
            if (platformFee > 0 && feeRecipient != address(0)) {
                IVault(_from).invokeTransfer( _premiumAsset,  feeRecipient,platformFee);         
            }
            IVault(_from).invokeTransfer( _premiumAsset,  _to, _premiumFee - platformFee );     
        }
    }

    function handleSignature(
        Signature memory _signatureInfo,
        address _signer,
        bytes memory _signature
    ) internal view {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        bytes32 _hashInfo=getHash(_signatureInfo);
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", optionFacet.getDomain(), _hashInfo)
        );
        address signer = IVault(_signer).owner();
        address recoverAddress = ECDSA.recover(digest, _signature);
        require(recoverAddress == signer, "OptionModule:signature error");
    }

    function getHash(Signature memory _signatureInfo) internal pure  returns(bytes32){
        bytes32 infoTypeHash = keccak256(
            "Signature(uint8 orderType,address underlyingAsset,uint8 underlyingAssetType,uint256 underlyingNftID,uint256 expirationDate,uint256 total,uint256 timestamp,uint8[] liquidateModes,address[] strikeAssets,uint256[] strikeAmounts,address[] premiumAssets,uint256[] premiumFees)"
        );
        bytes32 _hashInfo = keccak256(abi.encode(infoTypeHash,       
            _signatureInfo.orderType,
            _signatureInfo.underlyingAsset,
            _signatureInfo.underlyingAssetType,
            _signatureInfo.underlyingNftID,
            _signatureInfo.expirationDate,
            _signatureInfo.total,
            _signatureInfo.timestamp,
            keccak256(abi.encodePacked(_signatureInfo.liquidateModes)),
            keccak256(abi.encodePacked(_signatureInfo.strikeAssets)),
            keccak256(abi.encodePacked(_signatureInfo.strikeAmounts)),
            keccak256(abi.encodePacked(_signatureInfo.premiumAssets)),
            keccak256(abi.encodePacked(_signatureInfo.premiumFees))      
        ));
        return _hashInfo;
    }
    function checkTotalAndTimestamp(IOptionFacet.OrderType _orderType,Signature memory _signatureInfo,address _writer,uint256 _underlyingAmount) internal {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        uint256 timestamp=optionFacet.getSigatureLock(_writer,_orderType,_signatureInfo.underlyingAsset);
        uint256 total=optionFacet.getUnderlyTotal(_writer,_orderType,_signatureInfo.underlyingAsset);
        require(_signatureInfo.timestamp >=timestamp, "OptionModule:signature overdue");
        require(_signatureInfo.expirationDate>= block.timestamp,"OptionModule:expirationDate error");
        if(_signatureInfo.timestamp >timestamp && total==0){
            _underlyingAmount=_signatureInfo.total-_underlyingAmount;
            optionFacet.setUnderlyTotal(_writer,_orderType,_signatureInfo.underlyingAsset,_underlyingAmount);
            optionFacet.setSigatureLock(_writer,_orderType,_signatureInfo.underlyingAsset,_signatureInfo.timestamp);
        }
        if(_signatureInfo.timestamp == timestamp && total !=0){
            _underlyingAmount=total-_underlyingAmount;
            optionFacet.setUnderlyTotal(_writer,_orderType,_signatureInfo.underlyingAsset,_underlyingAmount);
            if(_underlyingAmount==0){
                optionFacet.setSigatureLock(_writer,_orderType,_signatureInfo.underlyingAsset,timestamp+1);
            }
        }     
    }
}