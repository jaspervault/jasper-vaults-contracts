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

    function submitJvaultOrder(SubmitJvaultOrder memory _info,bytes memory _writerSignature,bytes memory _holderSignature) external {
         handleJvaultSignature(_info,_writerSignature,_info.writer);
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
         handleFee(
                _info.holder,
                _info.writer,
                _info.premiumAsset,
                _info.premiumFee,
                _info.quantity
         );

        //create order
        if(_info.orderType==IOptionFacet.OrderType.Call){
             IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
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
             optionService.createCallOrder(callOrder);
             emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder,  _info.premiumAsset,  optionService.getParts(_info.quantity, _info.premiumFee));
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
             emit OptionPremiun(IOptionFacet.OrderType.Put ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder,  _info.premiumAsset,  optionService.getParts(_info.quantity, _info.premiumFee));
        }else{
            revert("OptionModule:orderType error");
        }
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
        require(
            !IVaultFacet(diamond).getVaultLock(_info.recipient),
            "OptionModule:recipient is locked"
        );
         IVault(_info.recipient).invokeTransfer(_info.premiumAsset,  _info.holder, optionService.getParts(_info.quantity, _info.premiumFee));
         handleFee(
                _info.holder,
                _info.writer,
                _info.premiumAsset,
                _info.premiumFee,
                _info.quantity
         );

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
    //----signature-----
    function setSigatureLock(
        Signature memory _sign,
        bytes calldata _writerSignature
    ) external onlyVaultManager(_sign.writer) {
        handleSignature(_sign, _sign.writer, _writerSignature);
        signBlackList[_writerSignature] = true;
    }


    //-----submit Order-----
    function submitOptionOrder(SubmitOrder memory _info,bytes memory _writerSignature) external  onlyVaultOrManager(_info.holder){   
        require(_info.optionSelect<=_info.signature.expirationDate.length,"OptionModule:premiumSelect error");
        require(
            _info.signature.lockDate.length== _info.signature.expirationDate.length&&
            _info.signature.liquidateModes.length== _info.signature.expirationDate.length&&
            _info.signature.strikeAssets.length== _info.signature.expirationDate.length&&
            _info.signature.strikeAmounts.length== _info.signature.expirationDate.length&&
            _info.signature.premiumAssets.length== _info.signature.expirationDate.length&&
            _info.signature.premiumFloor.length== _info.signature.expirationDate.length,"OptionModule:data length miss match");
        //verify signature
        handleSignature(_info.signature, _info.writer, _writerSignature);
        handlePremiumSign(_info.premiumSign);
        require(
            !IVaultFacet(diamond).getVaultLock(_info.recipient),
            "OptionModule:recipient is locked"
        );
         _info.premiumSign.premiumFee = _info.premiumSign.premiumFee>=_info.signature.premiumFloor[_info.optionSelect]?_info.premiumSign.premiumFee:_info.signature.premiumFloor[_info.optionSelect];
         uint premiumFee = optionService.getParts(_info.quantity,_info.premiumSign.premiumFee);
         IVault(_info.recipient).invokeTransfer(_info.signature.premiumAssets[_info.optionSelect],  _info.holder,premiumFee);

        //transfer fee
        handleFee(
                _info.holder,
                _info.writer,
                _info.signature.premiumAssets[_info.optionSelect],
                _info.premiumSign.premiumFee,
                _info.quantity
        );
        //create order
        if(_info.signature.orderType==IOptionFacet.OrderType.Call){
             IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
                holder:_info.holder,
                liquidateMode:_info.signature.liquidateModes[_info.optionSelect],
                writer:_info.writer,
                lockAssetType:_info.signature.lockAssetType,
                recipient:_info.recipient,
                lockAsset:_info.signature.lockAsset,
                underlyingAsset:_info.signature.underlyingAsset,
                strikeAsset:_info.signature.strikeAssets[_info.optionSelect],
                lockAmount:_info.signature.lockAmount,
                strikeAmount:_info.signature.strikeAmounts[_info.optionSelect],
                expirationDate:_info.signature.expirationDate[_info.optionSelect],
                lockDate:_info.signature.lockDate[_info.optionSelect],
                underlyingNftID:_info.signature.underlyingNftID,
                quantity:_info.quantity
             });
             optionService.createCallOrder(callOrder);
            emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder, _info.signature.premiumAssets[_info.optionSelect] , optionService.getParts(_info.quantity ,_info.premiumSign.premiumFee));

        }else if(_info.signature.orderType==IOptionFacet.OrderType.Put){
            IOptionFacet.PutOrder memory putOrder= IOptionFacet.PutOrder({
                        holder:_info.holder,
                        liquidateMode:_info.signature.liquidateModes[_info.optionSelect],
                        writer:_info.writer,
                        lockAssetType:_info.signature.lockAssetType,
                        recipient:_info.recipient,
                        lockAsset:_info.signature.lockAsset,
                        underlyingAsset:_info.signature.underlyingAsset,
                        strikeAsset:_info.signature.strikeAssets[_info.optionSelect],
                        lockAmount:_info.signature.lockAmount,
                        strikeAmount:_info.signature.strikeAmounts[_info.optionSelect],
                        expirationDate:_info.signature.expirationDate[_info.optionSelect],
                        lockDate:_info.signature.lockDate[_info.optionSelect],
                        underlyingNftID:_info.signature.underlyingNftID,
                        quantity:_info.quantity
             });
             optionService.createPutOrder(putOrder);
            emit OptionPremiun(IOptionFacet.OrderType.Put,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder, _info.signature.premiumAssets[_info.optionSelect] ,  optionService.getParts(_info.quantity ,_info.premiumSign.premiumFee));

        }else{
            revert("OptionModule:orderType error");
        }
    }

    function handleFee(
        address _from,
        address _to,
        address _premiumAsset,
        uint256 _premiumFee,
        uint256 _quantity
    ) internal {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        IPlatformFacet platformFacet=IPlatformFacet(diamond);
        address eth= platformFacet.getEth();
        //calculate premiumFee
        _premiumFee= optionService.getParts(_quantity, _premiumFee);   
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
            "Signature(uint8 orderType,address writer,uint256 lockAmount,address lockAsset,address underlyingAsset,uint8 lockAssetType,uint256 underlyingNftID,uint256[] expirationDate,uint256 total,uint256[] lockDate,uint8 liquidateModes,address[] strikeAssets,uint256[] strikeAmounts,address[] premiumAssets,uint256[] premiumFees,uint256[] premiumFloor)"
        );
        bytes32 _hashInfo = keccak256(abi.encode(
            infoTypeHash,
            getNewSignData(_signatureInfo),     
            keccak256(abi.encodePacked( _signatureInfo.expirationDate)),
            keccak256(abi.encodePacked( _signatureInfo.lockDate)),
            keccak256(abi.encodePacked( _signatureInfo.liquidateModes)),
            keccak256(abi.encodePacked( _signatureInfo.strikeAssets)),
            keccak256(abi.encodePacked( _signatureInfo.strikeAmounts)),
            keccak256(abi.encodePacked( _signatureInfo.premiumAssets)),
            keccak256(abi.encodePacked( _signatureInfo.premiumFloor))
        ));
         return _hashInfo;
    }
    struct NewSignData{
        IOptionFacet.OrderType orderType;
        address writer;
        uint256 lockAmount;
        address lockAsset;
        address underlyingAsset;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        uint256 underlyingNftID;
        uint256 total;
    }
    function getNewSignData(Signature memory _signatureInfo)internal pure returns (NewSignData memory data){
         data.orderType = _signatureInfo.orderType;
         data.writer = _signatureInfo.writer;
         data.lockAmount = _signatureInfo.lockAmount;
         data.lockAsset = _signatureInfo.lockAsset;
         data.underlyingAsset = _signatureInfo.underlyingAsset;
         data.lockAssetType = _signatureInfo.lockAssetType;
         data.underlyingNftID = _signatureInfo.underlyingNftID;
         data.total = _signatureInfo.total;
    }
    function handlePremiumSign(
        PremiumOracleSign memory _sign
    ) internal view {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        bytes32 infoTypeHash = keccak256(
            "PremiumOracleSign(uint64 id,uint8 productType,address optionAsset,uint256 strikePirce,uint256 expiredate,uint8 optionType,address premiumAsset,uint256 premiumFee,uint256 timestamp)");
        bytes32 _hashInfo = keccak256(abi.encode(
                infoTypeHash,       
                _sign.id,
                _sign.productType,
                _sign.optionAsset,
                _sign.strikePirce,
                _sign.expiredate,
                _sign.optionType,
                _sign.premiumAsset,
                _sign.premiumFee,
                _sign.timestamp
        ));        
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", optionFacet.getDomain(), _hashInfo)
        );
        for(uint i; i<_sign.oracleSign.length; i++) {
            require(oracleWhiteList[ECDSA.recover(digest, _sign.oracleSign[i])], "OptionModule:handlePremiumSign not from whiteList error");
        }
    }


}