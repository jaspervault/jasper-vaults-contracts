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
import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
import {INonfungiblePositionManager} from "../interfaces/external/INonfungiblePositionManager.sol";
import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";
import {IOptionModuleV2} from "../interfaces/internal/IOptionModuleV2.sol";
import {IPythAdapter} from "../interfaces/internal/IPythAdapter.sol";


contract OptionModuleV2Handle is  ModuleBase, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    using Invoke for IVault;
    IOptionModuleV2 public optionModuleV2;
    modifier onlyOwner() {
        require( msg.sender == IOwnable(diamond).owner(),"OptionService:only owner");  
        _;
    }
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _diamond,address _optionModuleV2) public initializer {
        __UUPSUpgradeable_init();
        diamond = _diamond;
        optionModuleV2=IOptionModuleV2(_optionModuleV2);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}


    function handlePremiumSign(
        IOptionModuleV2.PremiumOracleSign memory _sign
    ) public view {
        IOptionModuleV2.OptionPrice memory data = IOptionModuleV2.OptionPrice(
            _sign.id,
            _sign.chainId,
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
            "OptionPrice(uint256 id,uint256 chainId,uint64 productType,address optionAsset,uint256 strikePrice,address strikeAsset,uint256 strikeAmount,address lockAsset,uint256 lockAmount,uint256 expireDate,uint256 lockDate,uint8 optionType,address premiumAsset,uint256 premiumFee,uint256 timestamp)");
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
        for(uint256 i; i<_sign.oracleSign.length; i++) {
            require(optionModuleV2.getOracleWhiteList(ECDSA.recover(digest, _sign.oracleSign[i])), "OptionModule:handlePremiumSign not from whiteList error");
        }
    }    
    function isInArray(address[] memory array, address element) public pure returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }
    function verifyManagedOrder(IOptionModuleV2.ManagedOrder memory _info, IOptionFacetV2.ManagedOptionsSettings memory _setting) external view{
        require(_setting.isOpen, "OptionModule:isOpen error");
        require(!IVaultFacet(diamond).getVaultLock(_info.recipient)&&
                !IVaultFacet(diamond).getVaultLock(_info.holder)&&
                !IVaultFacet(diamond).getVaultLock(_info.writer),
                "OptionModule:vault is locked");
        require(_setting.writer == _info.writer,"OptionModule:writer error");
        require(_info.offerID == _setting.offerID,"OptionModule:offer id miss match");
        require(uint8(_setting.orderType) == _info.premiumSign.optionType,"OptionModule:optionType mismatch");
        require(_setting.lockAsset == _info.premiumSign.lockAsset,"OptionModule:lockAsset mismatch");
        require(_setting.underlyingAsset == _info.premiumSign.optionAsset,"OptionModule:underlyingAsset mismatch");
        require(_setting.strikeAsset == _info.premiumSign.strikeAsset,"OptionModule:strikeAsset mismatch");
        require(isInArray(_setting.premiumAssets,_info.premiumSign.premiumAsset),"OptionModule:premiumAsset mismatch");
        require(_setting.maximum>=_info.quantity, "OptionModule:maximum error");
        require(_setting.productTypes[_info.productTypeIndex] == _info.premiumSign.productType, "OptionModule:productType error");
        require(_info.premiumSign.strikeAmount >0, "OptionModule:strikeAmount error");
        require(_info.premiumSign.timestamp >= block.timestamp , "OptionModule:PremiumOracleSign timestamp expired");
        require(_info.premiumSign.chainId == block.chainid , "OptionModule:PremiumOracleSign chainid expired");
        require(_info.nftFreeOption == address(0)||optionModuleV2.getFeeDiscountWhitlist(_info.nftFreeOption), "OptionModule: nftFreeOption error");
        if(_info.premiumSign.optionType == uint8(IOptionFacet.OrderType.Call)){
            if(_setting.minUnderlyingAssetAmount!=0){
                require(_setting.minUnderlyingAssetAmount<=_info.premiumSign.strikeAmount,"OptionModuleV2: strikeAmount minUnderlyingAssetAmount error");
            }
            if(_setting.maxUnderlyingAssetAmount!=0){
                require(_info.premiumSign.strikeAmount<= _setting.maxUnderlyingAssetAmount,"OptionModuleV2:strikeAmount  maxUnderlyingAssetAmount error");
            }
        }else{
            if(_setting.minUnderlyingAssetAmount!=0){
                require(_setting.minUnderlyingAssetAmount<=_info.premiumSign.lockAmount,"OptionModuleV2:lockAmount minUnderlyingAssetAmount error");
            }
            if(_setting.maxUnderlyingAssetAmount!=0){
                require(_info.premiumSign.lockAmount<= _setting.maxUnderlyingAssetAmount,"OptionModuleV2:lockAmount maxUnderlyingAssetAmount error");
            }
        }
        if (_setting.minQuantity!=0){
             require(_setting.minQuantity<=_info.quantity,"OptionModuleV2:quantity less than setting minQuantity");
        }
        handlePremiumSign(_info.premiumSign);
    }


}
