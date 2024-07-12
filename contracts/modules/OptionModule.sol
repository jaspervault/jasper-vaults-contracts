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
import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";

contract OptionModule is ModuleBase,IOptionModule, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    using Invoke for IVault;
    IOptionService public optionService;
    struct SignData{
        bool lock;
        uint256 total;
        uint256 orderCount;
    }
    mapping(bytes=>SignData) public signData;
    mapping(address=>bool) public oracleWhiteList;
    string name;
    string version;
    // TODO: delete this
    mapping(bytes=>bool) public signBlackList;

    mapping(address=>mapping(uint256 => uint256)) premiunByAMMs;
    mapping(address=>bool) public nftWhiteList;
    IPriceOracle priceOracle;
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

    function setOptionPremiunByAMMs(address _token,uint256 _productType,uint256 _premiunRate) external onlyOwner{
        premiunByAMMs[_token][_productType] = _premiunRate;
    }
    function setOptionService(IOptionService _optionService) external onlyOwner{
        optionService=_optionService;
    }
    function setOracleWhiteList(address oracle) external onlyOwner{
        oracleWhiteList[oracle]=true;
    }
    function setPriceOracle(IPriceOracle _priceOracle) external onlyOwner{
        priceOracle = _priceOracle;
    }
    //----jvault-----degen  Single  
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
        if (_info.premiumAsset == IPlatformFacet(diamond).getEth()) { 
            IVault(_info.recipient).invokeTransferEth(_info.holder, optionService.getParts(_info.quantity, _info.premiumFee));
        }else{
            IVault(_info.recipient).invokeTransfer(_info.premiumAsset,  _info.holder, optionService.getParts(_info.quantity, _info.premiumFee));
        }
        handleFee(
                _info.holder,
                _info.writer,
                _info.premiumAsset,
                optionService.getParts( _info.quantity, _info.premiumFee)
               
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
        signData[_holderSignature].lock = true;
    }
    function SubmitManagedOrder(ManagedOrder memory _info) external  onlyVaultOrManager(_info.holder){   
        //verify signature
        IOptionFacet optionFacet = IOptionFacet(diamond);
        IOptionFacet.ManagedOptionsSettings memory setting = optionFacet.getManagedOptionsSettings(_info.writer);
        verifyManagedOrder(_info, setting);
        //transfer fee
        uint premiumFeePayed = handleSettingsFee(_info, setting);
        
        //create order
        if(setting.orderType==IOptionFacet.OrderType.Call){
             IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
                holder:_info.holder,
                liquidateMode:setting.liquidateMode,
                writer:setting.writer,
                lockAssetType:setting.lockAssetType,
                recipient:_info.recipient,
                lockAsset:setting.lockAsset,
                underlyingAsset:setting.underlyingAsset,
                strikeAsset:setting.strikeAsset,
                lockAmount:_info.premiumSign.lockAmount,
                strikeAmount:_info.premiumSign.strikeAmount,
                expirationDate:_info.premiumSign.expireDate,
                lockDate:_info.premiumSign.lockDate,
                underlyingNftID:setting.underlyingNftID,
                quantity:_info.quantity
             });
             optionService.createCallOrder(callOrder);
            emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  setting.writer,  _info.holder, setting.premiumAssets[_info.index] ,premiumFeePayed);
        }else if(setting.orderType==IOptionFacet.OrderType.Put){
            IOptionFacet.PutOrder memory putOrder= IOptionFacet.PutOrder({
                        holder:_info.holder,
                        liquidateMode:setting.liquidateMode,
                        writer:setting.writer,
                        lockAssetType:setting.lockAssetType,
                        recipient:_info.recipient,
                        lockAsset:setting.lockAsset,
                        underlyingAsset:setting.underlyingAsset,
                        strikeAsset:setting.strikeAsset,
                        lockAmount:_info.premiumSign.lockAmount,
                        strikeAmount:_info.premiumSign.strikeAmount,
                        expirationDate:_info.premiumSign.expireDate,
                        lockDate:_info.premiumSign.lockDate,
                        underlyingNftID:setting.underlyingNftID,
                        quantity:_info.quantity
             });
             optionService.createPutOrder(putOrder);
            emit OptionPremiun(IOptionFacet.OrderType.Put,  IOptionFacet(diamond).getOrderId(),  setting.writer,  _info.holder, setting.premiumAssets[_info.index], premiumFeePayed);
        }else{
            revert("OptionModule:orderType error");
        }

    }
    //-----submit Order-----
    // function submitOptionOrder(SubmitOrder memory _info) external  onlyVaultOrManager(_info.holder){   
    //     vaildSignature(_info);
    //     require(
    //         !IVaultFacet(diamond).getVaultLock(_info.recipient),
    //         "OptionModule:recipient is locked"
    //     );
    //      _info.premiumSign.premiumFee = _info.premiumSign.premiumFee>=_info.signature.premiumFloors[_info.optionSelect]?_info.premiumSign.premiumFee:_info.signature.premiumFloors[_info.optionSelect];
    //      uint premiumFee =_info.signature.premiumRates[_info.optionSelect] * optionService.getParts(_info.quantity,_info.premiumSign.premiumFee) / 1 ether;
    //      // pay the premium from recipient addr to holder
    //      IVault(_info.recipient).invokeTransfer(_info.signature.premiumAssets[_info.optionSelect],  _info.holder,premiumFee);

    //     //transfer fee
    //     handleFee(
    //             _info.holder,
    //             _info.writer,
    //             _info.signature.premiumAssets[_info.optionSelect],
    //             premiumFee
    //     );
    //     //create order
    //     if(_info.signature.orderType==IOptionFacet.OrderType.Call){
    //          IOptionFacet.CallOrder memory callOrder= IOptionFacet.CallOrder({
    //             holder:_info.holder,
    //             liquidateMode:_info.signature.liquidateModes[_info.optionSelect],
    //             writer:_info.writer,
    //             lockAssetType:_info.signature.lockAssetType,
    //             recipient:_info.recipient,
    //             lockAsset:_info.signature.lockAsset,
    //             underlyingAsset:_info.signature.underlyingAsset,
    //             strikeAsset:_info.signature.strikeAssets[_info.optionSelect],
    //             lockAmount:_info.signature.lockAmounts[_info.optionSelect],
    //             strikeAmount:_info.signature.strikeAmounts[_info.optionSelect],
    //             expirationDate:_info.signature.expirationDate[_info.optionSelect],
    //             lockDate:_info.signature.lockDate[_info.optionSelect],
    //             underlyingNftID:_info.signature.underlyingNftID,
    //             quantity:_info.quantity
    //          });
    //          optionService.createCallOrder(callOrder);
    //         emit OptionPremiun(IOptionFacet.OrderType.Call ,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder, _info.signature.premiumAssets[_info.optionSelect] , optionService.getParts(_info.quantity ,_info.premiumSign.premiumFee));

    //     }else if(_info.signature.orderType==IOptionFacet.OrderType.Put){
    //         IOptionFacet.PutOrder memory putOrder= IOptionFacet.PutOrder({
    //                     holder:_info.holder,
    //                     liquidateMode:_info.signature.liquidateModes[_info.optionSelect],
    //                     writer:_info.writer,
    //                     lockAssetType:_info.signature.lockAssetType,
    //                     recipient:_info.recipient,
    //                     lockAsset:_info.signature.lockAsset,
    //                     underlyingAsset:_info.signature.underlyingAsset,
    //                     strikeAsset:_info.signature.strikeAssets[_info.optionSelect],
    //                     lockAmount:_info.signature.lockAmounts[_info.optionSelect],
    //                     strikeAmount:_info.signature.strikeAmounts[_info.optionSelect],
    //                     expirationDate:_info.signature.expirationDate[_info.optionSelect],
    //                     lockDate:_info.signature.lockDate[_info.optionSelect],
    //                     underlyingNftID:_info.signature.underlyingNftID,
    //                     quantity:_info.quantity
    //          });
    //          optionService.createPutOrder(putOrder);
    //         emit OptionPremiun(IOptionFacet.OrderType.Put,  IOptionFacet(diamond).getOrderId(),  _info.writer,  _info.holder, _info.signature.premiumAssets[_info.optionSelect] ,  optionService.getParts(_info.quantity ,_info.premiumSign.premiumFee));

    //     }else{
    //         revert("OptionModule:orderType error");
    //     }
    // }

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
        require(recoverAddress == signer, "OptionModule:handleJvaultSignature signature error");
    }
    //----option------
    //----signature-----
    // function setSigatureLock(
    //     Signature memory _sign,
    //     bytes calldata _writerSignature
    // ) external onlyVaultOrManager(_sign.writer) {
    //     handleSignature(_sign, _sign.writer, _writerSignature);
    //     signData[_writerSignature].lock = true;
    // }

    // function vaildSignature(SubmitOrder memory _info)internal view{
    //     require(_info.optionSelect<_info.signature.expirationDate.length,"OptionModule:premiumSelect error");
    //     require(
    //         _info.signature.lockDate.length== _info.signature.expirationDate.length&&
    //         _info.signature.liquidateModes.length== _info.signature.expirationDate.length&&
    //         _info.signature.strikeAssets.length== _info.signature.expirationDate.length&&
    //         _info.signature.strikeAmounts.length== _info.signature.expirationDate.length&&
    //         _info.signature.premiumAssets.length== _info.signature.expirationDate.length&&
    //         _info.signature.premiumFloors.length== _info.signature.expirationDate.length,"OptionModule:data length mismatch");
    //     require(_info.signature.underlyingAsset == _info.premiumSign.optionAsset,"OptionModule:underlyingAsset mismatch");
    //     require(_info.signature.strikeAssets[_info.optionSelect] == _info.premiumSign.strikeAsset,"OptionModule:strikeAsset mismatch");
    //     require(_info.signature.lockAsset == _info.premiumSign.lockAsset,"OptionModule:lockAsset mismatch");
    //     require(_info.signature.expirationDate[_info.optionSelect] == _info.premiumSign.expireDate,"OptionModule:expireDate mismatch");
    //     require(_info.signature.lockDate[_info.optionSelect] == _info.premiumSign.lockDate,"OptionModule:lockDate mismatch");
    //     require(uint8(_info.signature.orderType) == _info.premiumSign.optionType,"OptionModule:optionType mismatch");
    //     require(_info.premiumSign.timestamp<= block.timestamp , "OptionModule:PremiumOracleSign timestamp expired");
    //     //verify signature
    //     handleSignature(_info.signature, _info.writer, _info.writerSign);
    //     handlePremiumSign(_info.premiumSign);
    // }

    function handleFee(
        address _from,
        address _to,
        address _premiumAsset,
        uint256 _premiumFee
    ) internal {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        IPlatformFacet platformFacet=IPlatformFacet(diamond);
        address eth= platformFacet.getEth();
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

    // function handleSignature(
    //     Signature memory _signatureInfo,
    //     address _signer,
    //     bytes memory _signature
    // ) internal view {
    //     IOptionFacet optionFacet = IOptionFacet(diamond);
    //     bytes32 _hashInfo=getHash(_signatureInfo);
    //     bytes32 digest = keccak256(
    //         abi.encodePacked("\x19\x01", optionFacet.getDomain(), _hashInfo)
    //     );
    //     address signer = IVault(_signer).owner();
    //     address recoverAddress = ECDSA.recover(digest, _signature);
    //     require(recoverAddress == signer, "OptionModule: handleSignature signature error");
    // }
    // function getHash(Signature memory _signatureInfo) internal pure  returns(bytes32){
    //     bytes32 infoTypeHash = keccak256(
    //         "Signature(uint8 orderType,address writer,address lockAsset,address underlyingAsset,uint8 lockAssetType,uint256 underlyingNftID,uint256 total,uint256[] lockAmounts,uint256[] expirationDate,uint256[] lockDate,uint8[] liquidateModes,address[] strikeAssets,uint256[] strikeAmounts,address[] premiumAssets,uint256[] premiumRates,uint256[] premiumFloors)"
    //     );
    //     bytes32 _hashInfo = keccak256(abi.encode(
    //         infoTypeHash,
    //         getNewSignData(_signatureInfo),     
    //         keccak256(abi.encodePacked( _signatureInfo.lockAmounts)),
    //         keccak256(abi.encodePacked( _signatureInfo.expirationDate)),
    //         keccak256(abi.encodePacked( _signatureInfo.lockDate)),
    //         keccak256(abi.encodePacked( _signatureInfo.liquidateModes)),
    //         keccak256(abi.encodePacked( _signatureInfo.strikeAssets)),
    //         keccak256(abi.encodePacked( _signatureInfo.strikeAmounts)),
    //         keccak256(abi.encodePacked( _signatureInfo.premiumAssets)),
    //         keccak256(abi.encodePacked( _signatureInfo.premiumRates)),
    //         keccak256(abi.encodePacked( _signatureInfo.premiumFloors))
    //     ));
    //     return _hashInfo;
    // }
    struct NewSignData{
        IOptionFacet.OrderType orderType;
        address writer;
        address lockAsset;
        address underlyingAsset;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        uint256 underlyingNftID;
        uint256 total;
    }
    // function getNewSignData(Signature memory _signatureInfo)internal pure returns (NewSignData memory data){
    //    return NewSignData(_signatureInfo.orderType,_signatureInfo.writer,_signatureInfo.lockAsset,_signatureInfo.underlyingAsset,_signatureInfo.lockAssetType,_signatureInfo.underlyingNftID,_signatureInfo.total);
    // }
    struct OptionPrice {
        uint256 id;
        uint8 productType;
        address optionAsset;
        uint256 strikePrice;
        address strikeAsset;
        uint256 strikeAmount;
        address lockAsset;
        uint256 lockAmount;
        uint256 expireDate;
        uint256 lockDate;
        uint8 optionType;
        address premiumAsset;
        uint256 premiumFee;
        uint256 timestamp;
    }
    function handlePremiumSign(
        PremiumOracleSign memory _sign
    ) internal view {
        OptionPrice memory data = OptionPrice(
            _sign.id,
            _sign.productType,
            _sign.optionAsset,
            _sign.strikePrice,
            _sign.strikeAsset,
            _sign.strikeAmount,
            _sign.lockAsset,
            _sign.lockAmount,
            _sign.expireDate,
            _sign.lockDate,
            _sign.optionType,
            _sign.premiumAsset,
            _sign.premiumFee,
            _sign.timestamp
        );
        bytes32 infoTypeHash = keccak256(
            "OptionPrice(uint256 id,uint8 productType,address optionAsset,uint256 strikePrice,address strikeAsset,uint256 strikeAmount,address lockAsset,uint256 lockAmount,uint256 expireDate,uint256 lockDate,uint8 optionType,address premiumAsset,uint256 premiumFee,uint256 timestamp)");
        bytes32 _hashInfo = keccak256(abi.encode(
                infoTypeHash,
                data
        ));
        bytes32 DomainInfoTypeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 _domain = keccak256(
            abi.encode(
                DomainInfoTypeHash,
                keccak256(bytes("OptionPrice")),
                keccak256(bytes("v1")),
                uint256(100),
                0xb2891C8004c4e70EC2F65A13885EB93B7be960AF
            )
        );        
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", _domain, _hashInfo)
        );
        for(uint i; i<_sign.oracleSign.length; i++) {
            require(oracleWhiteList[ECDSA.recover(digest, _sign.oracleSign[i])], "OptionModule:handlePremiumSign not from whiteList error");
        }
    }    
    function isInArray(address[] memory array, address element) public pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }

    function verifyManagedOrder(ManagedOrder memory _info, IOptionFacet.ManagedOptionsSettings memory _setting) internal view{
        require(_setting.isOpen, "OptionModule:isOpen error");
        require(!IVaultFacet(diamond).getVaultLock(_info.recipient)&&
                !IVaultFacet(diamond).getVaultLock(_info.holder)&&
                !IVaultFacet(diamond).getVaultLock(_info.writer),
                "OptionModule:vault is locked");
        require(_setting.writer == _info.writer,"OptionModule:writer error");
        require(uint8(_setting.orderType) == _info.premiumSign.optionType,"OptionModule:optionType mismatch");
        require(_setting.lockAsset == _info.premiumSign.lockAsset,"OptionModule:lockAsset mismatch");
        require(_setting.underlyingAsset == _info.premiumSign.optionAsset,"OptionModule:underlyingAsset mismatch");
        require(_setting.strikeAsset == _info.premiumSign.strikeAsset,"OptionModule:strikeAsset mismatch");
        require(isInArray(_setting.premiumAssets,_info.premiumSign.premiumAsset),"OptionModule:premiumAsset mismatch");
        require(_setting.maximum>=_info.quantity, "OptionModule:productType error");
        require(_setting.productTypes[_info.index] == _info.premiumSign.productType, "OptionModule:productType error");
        require(_info.premiumSign.strikeAmount >0, "OptionModule:strikeAmount error");
        require(_info.premiumSign.timestamp<= block.timestamp , "OptionModule:PremiumOracleSign timestamp expired");
        handlePremiumSign(_info.premiumSign);
    }

    function setManagedOptionsSettings(IOptionFacet.ManagedOptionsSettings memory _set) external onlyVaultOrManager(_set.writer){
        require(!IVaultFacet(diamond).getVaultLock(_set.writer),"OptionModule:writer is locked");
        IOptionFacet(diamond).setManagedOptionsSettings(_set);
    }
    function handleSettingsFee(ManagedOrder memory _info,IOptionFacet.ManagedOptionsSettings memory setting ) internal returns(uint256){
        uint256 premiumFeePayed;
        address eth = IPlatformFacet(diamond).getEth();
        address weth = IPlatformFacet(diamond).getWeth();
        uint256 premiumAssetPrice =  priceOracle.getUSDPriceSpecifyOracle(
            _info.premiumSign.premiumAsset == eth ? weth :  _info.premiumSign.premiumAsset,
            _info.oracleIndex);
        uint premiumDecimals =  uint(IERC20(_info.premiumSign.premiumAsset == eth ? weth : _info.premiumSign.premiumAsset).decimals());
        uint floorPremiumAmount =  10**36/premiumAssetPrice * setting.premiumFloorUSDs[_info.index] / 1 ether * 10**premiumDecimals/ 1 ether; 

        if (setting.premiumOracleType==IOptionFacet.PremiumOracleType.AMMS){
            uint256 premiumUSD = setting.premiumRates[_info.index] * priceOracle.getUSDPriceSpecifyOracle(setting.lockAsset == eth ? weth : setting.lockAsset, _info.oracleIndex) *_info.premiumSign.lockAmount /1 ether / 1 ether;
            uint premiumAmount = 10**36/premiumAssetPrice* premiumUSD / 1 ether * 10**premiumDecimals / 10** uint(IERC20(setting.lockAsset == eth ? weth : setting.lockAsset).decimals());
            premiumFeePayed=premiumAmount*premiumAssetPrice/ 10**premiumDecimals >= setting.premiumFloorUSDs[_info.index] ? premiumAmount :floorPremiumAmount ;
        }else if(setting.premiumOracleType==IOptionFacet.PremiumOracleType.PAMMS){
            uint premiumAmount = _info.premiumSign.premiumFee*setting.premiumRates[_info.index] / 1 ether;
            premiumFeePayed=premiumAmount*premiumAssetPrice/ 10**premiumDecimals >= setting.premiumFloorUSDs[_info.index] ? premiumAmount :floorPremiumAmount ;
        }
        premiumFeePayed =  optionService.getParts(_info.quantity,premiumFeePayed);
        if ( setting.premiumAssets[_info.index] ==eth){
            IVault(_info.recipient).invokeTransferEth(_info.holder, premiumFeePayed);
        }else{
            IVault(_info.recipient).invokeTransfer(setting.premiumAssets[_info.index],  _info.holder,premiumFeePayed);
        }
        handleFee(
                _info.holder,
                setting.writer,
                setting.premiumAssets[_info.index],
                premiumFeePayed
        );
        return premiumFeePayed;
    }
}