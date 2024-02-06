// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../lib/ModuleBase.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Invoke} from "../lib/Invoke.sol";
import {ILendFacet} from "../interfaces/internal/ILendFacet.sol";
import {IOptionModule} from "../interfaces/internal/IOptionModule.sol";
import {INonfungiblePositionManager} from "../interfaces/external/INonfungiblePositionManager.sol";

contract OptionModule is
    ModuleBase,
    IOptionModule,
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Invoke for IVault;
    using SafeERC20 for IERC20;
    mapping(uint256 => bool) public usedOrderCall;
    mapping(uint256 => bool) public usedOrderPut;
    modifier onlyOwner() {
        require(
            msg.sender == IOwnable(diamond).owner(),
            "OptionModule:only owner"
        );
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

    function verifyPutOrder(
        ILendFacet.PutOrder memory _putOrder
    ) internal view {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        IPlatformFacet platformFacet = IPlatformFacet(diamond);

		require(platformFacet.getTokenType(_putOrder.underlyingAsset) != 0, "OptionModule:underlyingAsset error");
		require(platformFacet.getTokenType(_putOrder.receiveAsset) != 0, "OptionModule:receiveAsset error");
        require(
            _putOrder.recipientAddress ==
                IVault(_putOrder.optionHolder).owner(),
            "OptionModule:recipientAddress error"
        );
        require(
            !usedOrderPut[_putOrder.orderID],
            "OptionModule:orderID is Used"
        );
        require(
            !vaultFacet.getVaultLock(_putOrder.optionHolder),
            "OptionModule:optionHolder is locked"
        );
        require(
            !vaultFacet.getVaultLock(_putOrder.optionWriter),
            "OptionModule:optionWriter is locked"
        );
        require(
            vaultFacet.getVaultType(_putOrder.optionHolder) == 3,
            "OptionModule:optionHolder vaultType error"
        );
        require(
            vaultFacet.getVaultType(_putOrder.optionWriter) == 2,
            "OptionModule:optionWriter vaultType error"
        );
        require(
            _putOrder.optionWriter != _putOrder.optionHolder,
            "OptionModule:optionWriter error"
        );
        require(
            _putOrder.expirationDate > block.timestamp,
            "OptionModule:invalid expirationDate"
        );
        require(
            _putOrder.receiveAmount >= _putOrder.receiveMinAmount,
            "OptionModule:receiveAmount error"
        );
      
        ILendFacet lendFacet = ILendFacet(diamond);
        address eth = platformFacet.getEth();
        //verify underlyingAsset
        if (_putOrder.underlyingAsset == eth) {
            require(
                _putOrder.optionHolder.balance >= _putOrder.underlyingAmount,
                "OptionModule:underlyingAmount not enough"
            );
        } else {
            if (_putOrder.underlyingAssetType == 0) {
                //verify token amount
                require(
                    IERC20(_putOrder.underlyingAsset).balanceOf(
                        _putOrder.optionHolder
                    ) >= _putOrder.underlyingAmount,
                    "OptionModule:underlyingAmount not enough"
                );
            } else if (_putOrder.underlyingAssetType == 1) {
                //verify uniswapv3 nft liquidity
                if (
                    lendFacet.getCollateralNft(_putOrder.underlyingAsset) ==
                    ILendFacet.CollateralNftType.UniswapV3
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

                    ) = INonfungiblePositionManager(_putOrder.underlyingAsset)
                            .positions(_putOrder.underlyingNftID);
                    require(
                        platformFacet.getTokenType(token0) != 0 &&
                            platformFacet.getTokenType(token1) != 0,
                        "OptionModule:nft assets error"
                    );
                    require(
                        uint256(liquidity) >= _putOrder.underlyingAmount,
                        "OptionModule:underlyingAmount not enough"
                    );
                } else {
                    revert("OptionModule:invalid Nft");
                }
            } else {
                revert("OptionModule:underlyingAssetType error");
            }
        }
        //verify receiveAsset
        if (_putOrder.receiveAsset == eth) {
            require(
                _putOrder.optionWriter.balance >= _putOrder.receiveAmount,
                "OptionModule:receiveAmount not enough"
            );
        } else {
            require(
                IERC20(_putOrder.receiveAsset).balanceOf(
                    _putOrder.optionWriter
                ) >= _putOrder.receiveAmount,
                "OptionModule:receiveAmount not enough"
            );
        }
    }

    function handlePutOrder(
        address _signer,
        ILendFacet.PutOrder memory _putOrder,
        bytes memory _signature
    ) internal view {
        ILendFacet.PutOrder memory tempInfo = ILendFacet.PutOrder({
            orderID: _putOrder.orderID,
            optionWriter: _putOrder.optionWriter,
            optionHolder: _putOrder.optionHolder,
            recipientAddress: _putOrder.recipientAddress,
            underlyingAsset: _putOrder.underlyingAsset,
            underlyingAmount: _putOrder.underlyingAmount,
            receiveAsset: _putOrder.receiveAsset,
            receiveMinAmount: _putOrder.receiveMinAmount,
            receiveAmount: _putOrder.receiveAmount,
            expirationDate: _putOrder.expirationDate,
            platformFeeAmount: _putOrder.platformFeeAmount,
            index: _putOrder.index,
            optionPremiumAmount: _putOrder.optionPremiumAmount,
            underlyingAssetType: _putOrder.underlyingAssetType,
            underlyingNftID: _putOrder.underlyingNftID
        });
        if (_signer == tempInfo.optionHolder) {
            tempInfo.receiveAmount = 0;
            tempInfo.optionWriter = address(0);
        }
        bytes32 infoTypeHash = keccak256(
            "PutOrder(uint256 orderID,address optionWriter,address optionHolder,address recipientAddress,address underlyingAsset,uint256 underlyingAmount,address receiveAsset,uint256 receiveMinAmount,uint256 receiveAmount,uint256 expirationDate,uint256 platformFeeAmount,uint256 index,uint256 optionPremiumAmount,uint256 underlyingAssetType,uint256 underlyingNftID)"
        );
        bytes32 _hashInfo = keccak256(abi.encode(infoTypeHash, tempInfo));
        verifySigbature(_signer, _hashInfo, _signature);
    }

    function submitPutOrder(
        ILendFacet.PutOrder memory _putOrder,
        bytes calldata _borrowerSignature,
        bytes calldata _lenderSignature
    ) external nonReentrant {
        //verify data
        verifyPutOrder(_putOrder);
        handlePutOrder(_putOrder.optionHolder, _putOrder, _borrowerSignature);
        handlePutOrder(_putOrder.optionWriter, _putOrder, _lenderSignature);
        //storage data
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        address eth = IPlatformFacet(diamond).getEth();
        vaultFacet.setVaultLock(_putOrder.optionHolder, true);
        ILendFacet lendFacet = ILendFacet(diamond);
        _putOrder.index = lendFacet.getLenderPutOrderLength(
            _putOrder.optionWriter
        );
        lendFacet.setBorrowerPutOrder(_putOrder.optionHolder, _putOrder);
        lendFacet.setLenderPutOrder(
            _putOrder.optionWriter,
            _putOrder.optionHolder
        );
        //tranfer lendFeePlatformRecipient
        address lendFeePlatformRecipient = lendFacet
            .getLendFeePlatformRecipient();
        usedOrderPut[_putOrder.orderID] = true;
        if (_putOrder.receiveAsset == eth) {
            if (lendFeePlatformRecipient != address(0)) {
                IVault(_putOrder.optionWriter).invokeTransferEth(
                    lendFeePlatformRecipient,
                    _putOrder.platformFeeAmount
                );
            }
            IVault(_putOrder.optionWriter).invokeTransferEth(
                _putOrder.recipientAddress,
                _putOrder.receiveAmount -
                    _putOrder.platformFeeAmount -
                    _putOrder.optionPremiumAmount
            );
        } else {
            if (lendFeePlatformRecipient != address(0)) {
                IVault(_putOrder.optionWriter).invokeTransfer(
                    _putOrder.receiveAsset,
                    lendFeePlatformRecipient,
                    _putOrder.platformFeeAmount
                );
            }
            //tranfer metamask
            IVault(_putOrder.optionWriter).invokeTransfer(
                _putOrder.receiveAsset,
                _putOrder.recipientAddress,
                _putOrder.receiveAmount -
                    _putOrder.platformFeeAmount -
                    _putOrder.optionPremiumAmount
            );
        }
        updatePosition(_putOrder.optionWriter, _putOrder.receiveAsset, 0);
        //set CurrentVaultModule
        setFuncBlackAndWhiteList(
            1,
            _putOrder.optionWriter,
            _putOrder.optionHolder,
            true
        );
        emit SubmitPutOrder(msg.sender, _putOrder);
    }

    function verifySigbature(
        address _signer,
        bytes32 _hash,
        bytes memory _signature
    ) internal view {
        bytes32 domainHash = ILendFacet(diamond).getDomainHash();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainHash, _hash)
        );
        address signer = IVault(_signer).owner();
        address recoverAddress = ECDSA.recover(digest, _signature);
        require(recoverAddress == signer, "OptionModule:signature error");
    }

    //liquidate
    /**
     -debtor  borrow
      _type=true:liqudate underlyingAsset
      _type=false:liqudate receiveAsset

     -loaner optionWriter 
        liqudate underlyingAsset
     */
    function liquidatePutOrder(
        address _borrower,
        bool _type
    ) external payable nonReentrant {
        ILendFacet lendFacet = ILendFacet(diamond);
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        ILendFacet.PutOrder memory putOrder = ILendFacet(diamond)
            .getBorrowerPutOrder(_borrower);

        require(
            putOrder.optionHolder != address(0),
            "OptionModule:putOrder not exist"
        );
        lendFacet.deleteBorrowerPutOrder(putOrder.optionHolder);
        vaultFacet.setVaultLock(putOrder.optionHolder, false);
        address owner = IVault(putOrder.optionHolder).owner();
        if (
            owner == msg.sender ||
            (IPlatformFacet(diamond).getIsVault(msg.sender) &&
                IOwnable(msg.sender).owner() == owner)
        ) {
            if (_type) {
                liquidate(putOrder, 1);
            } else {
                liquidate(putOrder, 2);
            }
        } else if (putOrder.expirationDate <= block.timestamp) {
            liquidate(putOrder, 1);
        } else {
            revert("OptionModule:liquidate time not yet");
        }
        lendFacet.deleteLenderPutOrder(putOrder.optionWriter, putOrder.index);
        setFuncBlackAndWhiteList(
            1,
            putOrder.optionWriter,
            putOrder.optionHolder,
            false
        );
        emit LiquidatePutOrder(msg.sender, putOrder);
    }

    function liquidate(
        ILendFacet.PutOrder memory _putOrder,
        uint256 _liquidateWay
    ) internal {
        address eth = IPlatformFacet(diamond).getEth();
        if (_liquidateWay == 1) {
            if (_putOrder.underlyingAsset == eth) {
                IVault(_putOrder.optionHolder).invokeTransferEth(
                    _putOrder.optionWriter,
                    _putOrder.underlyingAmount
                );
            } else {
                if (_putOrder.underlyingAssetType == 0) {
                    //transfer token
                    // IVault(_putOrder.debtor).invokeTransfer(_putOrder.underlyingAsset,_putOrder.loaner,_putOrder.underlyingAmount);
                    uint256 balance = IERC20(_putOrder.underlyingAsset)
                        .balanceOf(_putOrder.optionHolder);
                    IVault(_putOrder.optionHolder).invokeTransfer(
                        _putOrder.underlyingAsset,
                        _putOrder.optionWriter,
                        balance
                    );
                } else if (_putOrder.underlyingAssetType == 1) {
                    //transfer nft
                    IVault(_putOrder.optionHolder).invokeTransferNft(
                        _putOrder.underlyingAsset,
                        _putOrder.optionWriter,
                        _putOrder.underlyingNftID
                    );
                } else {
                    revert("OptionModule:underlyingAssetType error");
                }
            }
            updatePosition(
                _putOrder.optionHolder,
                _putOrder.underlyingAsset,
                0
            );
            updatePosition(
                _putOrder.optionWriter,
                _putOrder.underlyingAsset,
                0
            );
        } else if (_liquidateWay == 2) {
            //if receiveAsset == eth  repay asset is weth
            if (
                _putOrder.receiveAsset == eth &&
                msg.value >= _putOrder.receiveAmount
            ) {
                (bool success, ) = _putOrder.optionWriter.call{
                    value: _putOrder.receiveAmount
                }("");
                require(success, "OptionModule:trafer eth fail");
            } else {
                if (_putOrder.receiveAsset == eth) {
                    _putOrder.receiveAsset = IPlatformFacet(diamond).getWeth();
                }
                IERC20(_putOrder.receiveAsset).safeTransferFrom(
                    _putOrder.recipientAddress,
                    _putOrder.optionWriter,
                    _putOrder.receiveAmount
                );
            }
            updatePosition(
                _putOrder.optionWriter,
                _putOrder.receiveAsset,
                1,
                0
            );
        } else {
            revert("OptionModule:liquidateWay error");
        }
    }

    //--------------
    function verifyCallOrder(
        ILendFacet.CallOrder memory _callOrder
    ) internal view {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        require(platformFacet.getTokenType(_callOrder.underlyingAsset) != 0, "OptionModule:underlyingAsset error");
		require(platformFacet.getTokenType(_callOrder.optionPremiumAsset) != 0, "OptionModule:optionPremiumAsset error");
        require(
            _callOrder.optionHolderWallet ==
                IVault(_callOrder.optionHolder).owner(),
            "OptionModule:recipientAddress error"
        );
        require(
            !usedOrderCall[_callOrder.orderID],
            "OptionModule:orderID is Used"
        );
        require(
            !vaultFacet.getVaultLock(_callOrder.optionHolder),
            "OptionModule:optionHolder is locked"
        );
        require(
            !vaultFacet.getVaultLock(_callOrder.optionWriter),
            "OptionModule:optionWriter is locked"
        );
        require(
            vaultFacet.getVaultType(_callOrder.optionHolder) == 7,
            "OptionModule:optionHolder vaultType error"
        );
        require(
            vaultFacet.getVaultType(_callOrder.optionWriter) == 6,
            "OptionModule:optionWriter vaultType error"
        );
        require(
            _callOrder.optionHolder != _callOrder.optionWriter,
            "OptionModule:optionHolder error"
        );
        require(
            _callOrder.expirationDate > block.timestamp,
            "OptionModule:invalid expirationDate"
        );
        require(
            _callOrder.optionPremiumAmount >= _callOrder.optionPremiumMinAmount,
            "OptionModule:optionPremiumAmount error"
        );
        require(
            _callOrder.strikeNotionalAmount >=
                _callOrder.strikeNotionalMinAmount,
            "OptionModule:strikeNotionalAmount error"
        );
       
        ILendFacet lendFacet = ILendFacet(diamond);
        address eth = platformFacet.getEth();
        //verify underlyingAsset
        if (_callOrder.underlyingAsset == eth) {
            require(
                _callOrder.optionWriter.balance >= _callOrder.underlyingAmount,
                "OptionModule:underlyingAmount not enough"
            );
        } else {
            if (_callOrder.underlyingAssetType == 0) {
                require(
                    IERC20(_callOrder.underlyingAsset).balanceOf(
                        _callOrder.optionWriter
                    ) >= _callOrder.underlyingAmount,
                    "OptionModule:underlyingAmount not enough"
                );
            } else if (_callOrder.underlyingAssetType == 1) {
                //verify uniswapv3 nft liquidity
                if (
                    lendFacet.getCollateralNft(_callOrder.underlyingAsset) ==
                    ILendFacet.CollateralNftType.UniswapV3
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

                    ) = INonfungiblePositionManager(_callOrder.underlyingAsset)
                            .positions(_callOrder.underlyingNftID);
                    require(
                        platformFacet.getTokenType(token0) != 0 &&
                            platformFacet.getTokenType(token1) != 0,
                        "OptionModule:nft assets error"
                    );
                    require(
                        uint256(liquidity) >= _callOrder.underlyingAmount,
                        "OptionModule:underlyingAmount not enough"
                    );
                } else {
                    revert("OptionModule:invalid Nft");
                }
            } else {
                revert("OptionModule:underlyingAssetType error");
            }
        }
        //verify lendAsset
        if (_callOrder.optionPremiumAsset == eth) {
            require(
                _callOrder.optionHolder.balance >=
                    (_callOrder.optionPremiumAmount +
                        _callOrder.xFeeAmount +
                        _callOrder.platformFeeAmount),
                "OptionModule:receiveAmount not enough"
            );
        } else {
            require(
                IERC20(_callOrder.optionPremiumAsset).balanceOf(
                    _callOrder.optionHolder
                ) >=
                    (_callOrder.optionPremiumAmount +
                        _callOrder.xFeeAmount +
                        _callOrder.platformFeeAmount),
                "OptionModule:receiveAmount not enough"
            );
        }
    }

    function handleCallOrderr(
        address _signer,
        ILendFacet.CallOrder memory _callOrder,
        bytes memory _signature
    ) internal view {
        ILendFacet.CallOrder memory tempInfo = ILendFacet.CallOrder({
            orderID: _callOrder.orderID,
            optionHolder: _callOrder.optionHolder,
            optionWriter: _callOrder.optionWriter,
            optionHolderWallet: _callOrder.optionHolderWallet,
            underlyingAsset: _callOrder.underlyingAsset,
            underlyingAmount: _callOrder.underlyingAmount,
            optionPremiumAsset: _callOrder.optionPremiumAsset,
            optionPremiumAmount: _callOrder.optionPremiumAmount,
            optionPremiumMinAmount: _callOrder.optionPremiumMinAmount,
            xFeeAmount: _callOrder.xFeeAmount,
            strikeNotionalMinAmount: _callOrder.strikeNotionalMinAmount,
            strikeNotionalAmount: _callOrder.strikeNotionalAmount,
            expirationDate: _callOrder.expirationDate,
            platformFeeAmount: _callOrder.platformFeeAmount,
            index: _callOrder.index,
            underlyingAssetType: _callOrder.underlyingAssetType,
            underlyingNftID: _callOrder.underlyingNftID
        });
        if (_signer == tempInfo.optionHolder) {
            // tempInfo.optionPremiumAmount = 0;
            // tempInfo.strikeNotionalAmount = 0;
            tempInfo.optionWriter = address(0);
        }
        bytes32 infoTypeHash = keccak256(
            "CallOrder(uint256 orderID,address optionHolder,address optionWriter,address optionHolderWallet,address underlyingAsset,uint256 underlyingAmount,address optionPremiumAsset,uint256 optionPremiumAmount,uint256 optionPremiumMinAmount,uint256 xFeeAmount,uint256 strikeNotionalMinAmount,uint256 strikeNotionalAmount,uint256 expirationDate,uint256 platformFeeAmount,uint256 index,uint256 underlyingAssetType,uint256 underlyingNftID)"
        );
        bytes32 _hashInfo = keccak256(abi.encode(infoTypeHash, tempInfo));
        verifySigbature(_signer, _hashInfo, _signature);
    }

    function submitCallOrder(
        ILendFacet.CallOrder memory _callOrder,
        bytes calldata _borrowerSignature,
        bytes calldata _lenderSignature
    ) external nonReentrant {
        verifyCallOrder(_callOrder);
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        handleCallOrderr(_callOrder.optionWriter, _callOrder, _lenderSignature);
        handleCallOrderr(
            _callOrder.optionHolder,
            _callOrder,
            _borrowerSignature
        );
        ILendFacet lendFacet = ILendFacet(diamond);
        //store data
        _callOrder.index = lendFacet.getBorrowerCallOrderLength(_callOrder.optionWriter);
        lendFacet.setLenderCallOrder(_callOrder.optionHolder, _callOrder);
        lendFacet.setBorrowerCallOrder(_callOrder.optionWriter,_callOrder.optionHolder); 
        usedOrderCall[_callOrder.orderID] = true;
        //tranfer lendFeePlatformRecipient
        address lendFeePlatformRecipient = lendFacet
            .getLendFeePlatformRecipient();
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        address eth = platformFacet.getEth();
        if (_callOrder.optionPremiumAsset == eth) {
            if (lendFeePlatformRecipient != address(0)) {
                IVault(_callOrder.optionHolder).invokeTransferEth(
                    lendFeePlatformRecipient,
                    _callOrder.platformFeeAmount
                );
            }
            IVault(_callOrder.optionHolder).invokeTransferEth(
                _callOrder.optionWriter,
                (_callOrder.optionPremiumAmount + _callOrder.xFeeAmount)
            );
        } else {
            if (lendFeePlatformRecipient != address(0)) {
                IVault(_callOrder.optionHolder).invokeTransfer(
                    _callOrder.optionPremiumAsset,
                    lendFeePlatformRecipient,
                    _callOrder.platformFeeAmount
                );
            }
            IVault(_callOrder.optionHolder).invokeTransfer(
                _callOrder.optionPremiumAsset,
                _callOrder.optionWriter,
                (_callOrder.optionPremiumAmount + _callOrder.xFeeAmount)
            );
        }
        //transfer uunderlyingAsset
        if (_callOrder.underlyingAsset == eth) {
            IVault(_callOrder.optionWriter).invokeTransferEth(
                _callOrder.optionHolder,
                _callOrder.underlyingAmount
            );
        } else {
            if (_callOrder.underlyingAssetType == 0) {
                IVault(_callOrder.optionWriter).invokeTransfer(
                    _callOrder.underlyingAsset,
                    _callOrder.optionHolder,
                    _callOrder.underlyingAmount
                );
            } else if (_callOrder.underlyingAssetType == 1) {
                IVault(_callOrder.optionWriter).invokeTransferNft(
                    _callOrder.underlyingAsset,
                    _callOrder.optionHolder,
                    _callOrder.underlyingNftID
                );
            } else {
                revert("OptionModule:underlyingAssetType error");
            }
        }
        //update position
        updatePosition(
            _callOrder.optionHolder,
            _callOrder.optionPremiumAsset,
            0
        );
        updatePosition(_callOrder.optionHolder, _callOrder.underlyingAsset, 0);
        updatePosition(_callOrder.optionWriter, _callOrder.underlyingAsset, 0);
        //set CurrentVaultModule
        setFuncBlackAndWhiteList(
            2,
            _callOrder.optionHolder,
            _callOrder.optionWriter,
            true
        );
        vaultFacet.setVaultLock(_callOrder.optionHolder, true);
        emit SubmitCallOrder(msg.sender, _callOrder);
    }

    function liquidateCallOrder(
        address _optionHolder,
        bool _type
    ) external payable nonReentrant {
        ILendFacet lendFacet = ILendFacet(diamond);
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        ILendFacet.CallOrder memory callOrder = ILendFacet(diamond).getLenderCallOrder(_optionHolder);  
        require( callOrder.optionHolder != address(0),"OptionModule:callOrder not exist" );
        lendFacet.deleteLenderCallOrder(callOrder.optionHolder);
        vaultFacet.setVaultLock(callOrder.optionHolder, false);
        address owner = IVault(callOrder.optionHolder).owner();   
        if (msg.sender == owner ||  (IPlatformFacet(diamond).getIsVault(msg.sender) && IOwnable(msg.sender).owner() == owner) ) {
            if (_type) {
                liquidateCall(callOrder,true);
            }else{
                liquidateCall(callOrder,false);
            }
        } else if (block.timestamp > callOrder.expirationDate) {
                liquidateCall(callOrder,false);             
        } else {
            revert("OptionModule:liquidate time not yet");
        }
        lendFacet.deleteLenderCallOrder(callOrder.optionWriter,callOrder.index);
        setFuncBlackAndWhiteList(2,callOrder.optionHolder, callOrder.optionWriter,false);
        emit LiquidateCallOrder(msg.sender, callOrder);
    }

    function liquidateCall(ILendFacet.CallOrder memory callOrder,bool isType) internal {
         IPlatformFacet platformFacet = IPlatformFacet(diamond);
         address eth = platformFacet.getEth();
         if(isType){
            //payLater time
                //traferFrom optionPremiumAsset to optionWriter
                if (callOrder.optionPremiumAsset == eth) {
                    callOrder.optionPremiumAsset = platformFacet.getWeth();
                }
                IERC20(callOrder.optionPremiumAsset).safeTransferFrom( callOrder.optionHolderWallet,callOrder.optionWriter,callOrder.strikeNotionalAmount);    
                updatePosition(callOrder.optionWriter,callOrder.optionPremiumAsset,0); 
         }else{
           //unlock
            if (callOrder.underlyingAssetType == 0) {
                if (callOrder.underlyingAsset == eth) {
                    IVault(callOrder.optionHolder).invokeTransferEth(callOrder.optionWriter, callOrder.underlyingAmount);                     
                } else {
                    uint256 balance = IERC20(callOrder.underlyingAsset).balanceOf(callOrder.optionHolder);                          
                    IVault(callOrder.optionHolder).invokeTransfer(callOrder.underlyingAsset,callOrder.optionWriter,balance);                   
                }
            } else if (callOrder.underlyingAssetType == 1) {
                IVault(callOrder.optionHolder).invokeTransferNft(callOrder.underlyingAsset, callOrder.optionWriter, callOrder.underlyingNftID);       
            } else {
                revert("OptionModule:underlyingAssetType error");
            }
            updatePosition(callOrder.optionHolder,callOrder.underlyingAsset,0);     
            updatePosition(callOrder.optionWriter,callOrder.underlyingAsset,0);  
         }
    }

    function setFuncBlackAndWhiteList(
        uint256 _orderType,
        address _blacker,
        address _whiter,
        bool _type
    ) internal {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        ILendFacet lendFacet = ILendFacet(diamond);
        if (
            (_orderType == 1 &&
                lendFacet.getLenderPutOrderLength(_blacker) == 0) ||
            (_orderType == 2 &&
                lendFacet.getBorrowerCallOrderLength(_blacker) == 0)
        ) {
            vaultFacet.setFuncBlackList(
                _blacker,
                bytes4(keccak256("setVaultType(address,uint256)")),
                _type
            );
        }
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
            bytes4(keccak256("liquidateStakeOrder(address,bool)")),
            _type
        );
    }
}
