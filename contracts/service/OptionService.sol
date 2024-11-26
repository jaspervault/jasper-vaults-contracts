// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../lib/ModuleBase.sol";

import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {Invoke} from "../lib/Invoke.sol";
import {IOptionService} from "../interfaces/internal/IOptionService.sol";
import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
import {INonfungiblePositionManager} from "../interfaces/external/INonfungiblePositionManager.sol";
import {IOptionLiquidateService} from "../interfaces/internal/IOptionLiquidateService.sol";

contract OptionService is  ModuleBase,IOptionService, Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    using Invoke for IVault;
    address public priceOracle;
    mapping(address=>bool) public whiteList;
    // todo 
    IOptionLiquidateService public liquidateSerivce;

    modifier onlyOwner() {
        require( msg.sender == IOwnable(diamond).owner(),"OptionService:only owner");  
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
    function setLiquidateSerivce(IOptionLiquidateService _addr) external onlyOwner{
        liquidateSerivce = _addr;
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
        require(_verifyOrder.quantity > 0, "OptionService: quantity is 0");
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
        if (_verifyOrder.lockDate != 0){
            require(
                    _verifyOrder.lockDate  > block.timestamp &&  _verifyOrder.expirationDate >= _verifyOrder.lockDate,
                    "OptionService:invalid lockDate"
            );
        }

        require(
            _verifyOrder.writer != _verifyOrder.holder,
            "OptionService:holder error"
        );
    
        uint optionLockAmount = getParts(_verifyOrder.quantity,_verifyOrder.lockAmount);

        if (
            _verifyOrder.lockAssetType ==
            IOptionFacet.UnderlyingAssetType.Original
        ) {
            require(
                _verifyOrder.writer.balance >= optionLockAmount,
                "OptionService:lockAmount not enough"
            );

            IVault(_verifyOrder.writer).invokeTransferEth(
                _verifyOrder.holder,
                optionLockAmount
            );
        } else if (
            _verifyOrder.lockAssetType ==
            IOptionFacet.UnderlyingAssetType.Token
        ) {

            require(
                IERC20(_verifyOrder.lockAsset).balanceOf(
                    _verifyOrder.writer
                ) >= optionLockAmount,
                "OptionService:lockAmount not enough"
            );

            IVault(_verifyOrder.writer).invokeTransfer(
                _verifyOrder.lockAsset,
                _verifyOrder.holder,
                optionLockAmount
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

    function setFuncWhiteList(address _user, bool _type) internal {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        vaultFacet.setFuncWhiteList(
            _user,
            bytes4(
                keccak256(
                    "replacementLiquidity(address,uint8,uint24,int24,int24)"
                )
            ),
            _type
        );
        vaultFacet.setFuncWhiteList(
            _user,
            bytes4(
                keccak256(
                    "liquidateOption(uint8,uint64,uint8,uint256,uint256)"
                )
            ),
            _type
        );
        vaultFacet.setFuncWhiteList(
            _user,
            bytes4(
                keccak256(
                    "setPrice(address,bytes[])"
                )
            ),
            _type
        );
    }
    function getParts(uint256 quantity ,uint256 strikeAmount)  public pure returns(uint256){
          return quantity*strikeAmount/ 1 ether;
    }

    //-------liquidate-------- todo
    function liquidateOption(
        LiquidateParams memory _params
    ) external payable nonReentrant{
        LiquidateResult memory result = liquidateSerivce.liquidateOption(
            _params,
            msg.sender);
        emit LiquidateOption(_params._orderType,_params._orderID, _params._type,_params._index,result);
    }
}
