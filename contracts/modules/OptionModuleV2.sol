// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../lib/ModuleBase.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {Invoke} from "../lib/Invoke.sol";
import {IOptionModuleV2} from "../interfaces/internal/IOptionModuleV2.sol";
import {IOptionService} from "../interfaces/internal/IOptionService.sol";
import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";
import {INFTFreeOptionPool} from "../interfaces/external/INFTFreeOptionPool.sol";
import {IOptionModuleV2Handle} from "../interfaces/internal/IOptionModuleV2Handle.sol";

contract OptionModuleV2 is ModuleBase,IOptionModuleV2, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    using Invoke for IVault;
    IOptionService public optionService;
    IPriceOracle priceOracleModule;

    struct SignData{
        bool lock;
        uint256 total;
        uint256 orderCount;
    }
    mapping(bytes=>SignData) public signData;
    mapping(address=>bool) public oracleWhiteList;
    mapping(address=>bool) public feeDiscountWhitlist;
    IOptionModuleV2Handle public optionModuleV2Handle;
    modifier onlyOwner() {
        require( msg.sender == IOwnable(diamond).owner(),"OptionModule:only owner");  
        _;
    }
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _diamond,address _optionService,address _priceOracleModule) public initializer {
        __UUPSUpgradeable_init();
        diamond = _diamond;
        optionService = IOptionService(_optionService);
        priceOracleModule = IPriceOracle(_priceOracleModule);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}


    function setOptionService(IOptionService _optionService) external onlyOwner{
        optionService=_optionService;
    }
    function setOracleWhiteList(address _oracleSigner,bool _status) external onlyOwner{
        emit SetOracleWhiteList(_oracleSigner);
        oracleWhiteList[_oracleSigner]=_status;
    }
    function setPriceOracle(IPriceOracle _priceOracleModule) external onlyOwner{
        emit SetPriceOracle(address(_priceOracleModule));
        priceOracleModule = _priceOracleModule;
    }
    function setFeeDiscountWhitlist(address _pool,bool _status) external onlyOwner{
        emit SetFeeDiscountWhitlist(_pool);
        feeDiscountWhitlist[_pool] = _status;
    }
    function setOptionModuleV2Handle(address _hanlde) external onlyOwner{
        emit SetOptionModuleV2Handle(_hanlde);
        optionModuleV2Handle = IOptionModuleV2Handle(_hanlde);
    }
    function handleManagedOrder(ManagedOrder memory _info) public onlyModule{
        //verify signature
        IOptionFacetV2 optionFacetV2 = IOptionFacetV2(diamond);
        IOptionFacetV2.ManagedOptionsSettings memory setting = optionFacetV2.getManagedOptionsSettingsByIndex(_info.writer,_info.settingsIndex);
        optionModuleV2Handle.verifyManagedOrder(_info, setting);
        //transfer fee
        uint256 premiumFeeToPay = transferManagedFee(_info, setting);
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
            IOptionFacetV2(diamond).setOptionExtraData(IOptionFacet(diamond).getOrderId(), IOptionFacetV2.OptionExtra(
                setting.productTypes[_info.productTypeIndex],
                _info.optionSourceType,
                _info.liquidationToEOA
            ));
            updatePosition(_info.writer,_info.premiumSign.premiumAsset,0);
            emit OptionPremiun(IOptionFacet.OrderType.Call, IOptionFacet(diamond).getOrderId(),  setting.writer,  _info.holder, _info.premiumSign.premiumAsset,premiumFeeToPay);
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
            updatePosition(_info.writer,_info.premiumSign.premiumAsset,0);
            IOptionFacetV2(diamond).setOptionExtraData(IOptionFacet(diamond).getOrderId(),  IOptionFacetV2.OptionExtra(
                setting.productTypes[_info.productTypeIndex],
                _info.optionSourceType,
                _info.liquidationToEOA            
            ));
            emit OptionPremiun(IOptionFacet.OrderType.Put,IOptionFacet(diamond).getOrderId(),setting.writer,_info.holder,_info.premiumSign.premiumAsset,premiumFeeToPay);
        }else{
            revert("OptionModule:orderType error");
        }
    }
    function SubmitManagedOrder(ManagedOrder memory _info) external nonReentrant onlySameOwnerVault(_info.holder){
        IOptionModuleV2(address(this)).handleManagedOrder(_info);
    }
    function handleManagedFee(
        ManagedOrder memory _info,
        uint256 _premiumFeeToPay
    ) internal {
        IOptionFacet optionFacet = IOptionFacet(diamond);
        IPlatformFacet platformFacet=IPlatformFacet(diamond);
        address eth= platformFacet.getEth();
        //calculate premiumFee
        //calculate platformFee
        uint256 platformFee = (_premiumFeeToPay * optionFacet.getFeeRate()) / 1 ether;           
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
        uint256 freeOptionAmount;
        uint256 holderPayOptionAmount;
        if (_info.nftFreeOption!=address(0)){
            uint256 freeAmount = INFTFreeOptionPool(_info.nftFreeOption).getFreeAmount(_info);
            if (freeAmount <= _premiumFeeToPay ){
                freeOptionAmount = freeAmount;
                holderPayOptionAmount = _premiumFeeToPay - freeAmount;
            }else{
                freeOptionAmount = _premiumFeeToPay;
            }
        }else{
            holderPayOptionAmount=_premiumFeeToPay;
        }
        if (_info.nftFreeOption!=address(0)&&freeOptionAmount>0){
            require(INFTFreeOptionPool(_info.nftFreeOption).submitFreeAmount(_info, freeOptionAmount),"OptionModule:submitFreeAmount error");
        }
        if (_info.premiumSign.premiumAsset == eth) {
                if (freeOptionAmount>0){
                    IVault(_info.nftFreeOption).invokeTransferEth(_info.holder, freeOptionAmount);
                }
                if (holderPayOptionAmount>0){
                    IVault(_info.recipient).invokeTransferEth(_info.holder, holderPayOptionAmount);
                }
                if (platformFee > 0 && feeRecipient != address(0)) {
                    IVault(_info.holder).invokeTransferEth(feeRecipient, platformFee);
                }
                if( _premiumFeeToPay - platformFee>0){
                    IVault(_info.holder).invokeTransferEth(_info.writer, _premiumFeeToPay - platformFee);
                }
            } else {
                if (freeOptionAmount>0){
                    IVault(_info.nftFreeOption).invokeTransfer(_info.premiumSign.premiumAsset, _info.holder, freeOptionAmount);
                }
                if (holderPayOptionAmount>0){
                    IVault(_info.recipient).invokeTransfer(_info.premiumSign.premiumAsset, _info.holder, holderPayOptionAmount);
                }
                if (platformFee > 0 && feeRecipient != address(0)) {
                    IVault(_info.holder).invokeTransfer( _info.premiumSign.premiumAsset,feeRecipient,platformFee);         
                }
                if( _premiumFeeToPay - platformFee>0){
                    IVault(_info.holder).invokeTransfer(_info.premiumSign.premiumAsset, _info.writer, _premiumFeeToPay - platformFee );     
                }
            }

    }

    function transferManagedFee(ManagedOrder memory _info,IOptionFacetV2.ManagedOptionsSettings memory setting) internal returns(uint256 premiumFeeToPay){
        address eth = IPlatformFacet(diamond).getEth();
        address weth = IPlatformFacet(diamond).getWeth();
        uint256 premiumAmount;
        uint256 premiumAssetPrice =  priceOracleModule.getUSDPriceSpecifyOracle(
            _info.premiumSign.premiumAsset == eth ? weth :  _info.premiumSign.premiumAsset,
            _info.oracleIndex);
        uint256 premiumDecimals =  uint256(IERC20(_info.premiumSign.premiumAsset == eth ? weth : _info.premiumSign.premiumAsset).decimals());
        uint256 premiumFloorAmount = getPremiumFloorAmount(_info,setting,eth,weth,premiumAssetPrice,premiumDecimals);
        if (setting.premiumOracleType==IOptionFacetV2.PremiumOracleType.AMMS){
            uint256 premiumUSD = setting.premiumRates[_info.productTypeIndex] * priceOracleModule.getUSDPriceSpecifyOracle(setting.lockAsset == eth ? weth : setting.lockAsset, _info.oracleIndex)*_info.premiumSign.lockAmount / 1 ether ;
            premiumAmount = 10**36/premiumAssetPrice*premiumUSD
             * 10**premiumDecimals / 1 ether / 10** uint256(IERC20(setting.lockAsset == eth ? weth : setting.lockAsset).decimals())/ 1 ether;
            premiumFeeToPay=premiumAmount >= premiumFloorAmount ? premiumAmount :premiumFloorAmount ;
        }else if(setting.premiumOracleType==IOptionFacetV2.PremiumOracleType.PAMMS){
            premiumAmount = _info.premiumSign.premiumFee*setting.premiumRates[_info.productTypeIndex] / 1 ether;
            premiumFeeToPay=premiumAmount >= premiumFloorAmount ? premiumAmount :premiumFloorAmount ;
        }
        premiumFeeToPay = optionService.getParts(_info.quantity,premiumFeeToPay);
        handleManagedFee(_info,premiumFeeToPay);
        return premiumFeeToPay;
    }
    function getPremiumFloorAmount(ManagedOrder memory _info,IOptionFacetV2.ManagedOptionsSettings memory setting,address eth, address weth,uint256 premiumAssetPrice,uint256 premiumDecimals) internal view returns(uint256 premiumFloorAmount) {
        uint256 preMiumFloorUSD =  setting.premiumFloorAMMs[_info.productTypeIndex] * priceOracleModule.getUSDPriceSpecifyOracle(setting.lockAsset == eth ? weth : setting.lockAsset, _info.oracleIndex)  *_info.premiumSign.lockAmount / 1 ether ;
        premiumFloorAmount = 10 ** 36/ premiumAssetPrice* preMiumFloorUSD  * 10**premiumDecimals / 1 ether / 10** uint256(IERC20(setting.lockAsset == eth ? weth : setting.lockAsset).decimals())/ 1 ether;
    }

    function setManagedOptionsSettings(
        IOptionFacetV2.ManagedOptionsSettings[] memory _set,
        address _vault,
        uint256[] memory _deleteIndex) external onlySameOwnerVault(_vault){
        address eth = IPlatformFacet(diamond).getEth();
        for (uint i = 0; i < _set.length; i++) {
            require(!IVaultFacet(diamond).getVaultLock(_set[i].writer),"OptionModule:writer is locked");
            require(_set[i].writer==_vault,"OptionModule:writer error");
            require(_set[i].productTypes.length ==_set[i].premiumFloorAMMs.length
            && _set[i].productTypes.length==_set[i].premiumRates.length ,
            "OptionModule:ManagedOptionsSettings length not same");
            if(_set[i].lockAsset!=eth){
                require(_set[i].lockAssetType!=IOptionFacet.UnderlyingAssetType.Original,"OptionModule:set lockAssetType Original missMatch");
            }
            require(_set[i].lockAsset != _set[i].strikeAsset,"OptionModule:set error");
            if (_set[i].maxUnderlyingAssetAmount>0 && _set[i].minUnderlyingAssetAmount>0){
                require(_set[i].maxUnderlyingAssetAmount>=_set[i].minUnderlyingAssetAmount,"OptionModule:set OptionModule minUnderlyingAssetAmount less than maxUnderlyingAssetAmount");
            }
        }
        IOptionFacetV2(diamond).setManagedOptionsSettings(_set,_vault,_deleteIndex);
    }
    function getManagedOptionsSettings(address _vault) external view returns(IOptionFacetV2.ManagedOptionsSettings[] memory){
        IOptionFacetV2 optionFacetV2 = IOptionFacetV2(diamond);
        return optionFacetV2.getManagedOptionsSettings(_vault);
    }
    function getFeeDiscountWhitlist(address _nft)external view returns(bool){
        return feeDiscountWhitlist[_nft];
    }
    function getOracleWhiteList(address _addr) external view returns(bool){
        return oracleWhiteList[_addr];
    }
}