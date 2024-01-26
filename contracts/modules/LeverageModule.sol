// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../lib/ModuleBase.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Invoke} from "../lib/Invoke.sol";
import {ILeverageFacet} from "../interfaces/internal/ILeverageFacet.sol";
import {ILendFacet} from "../interfaces/internal/ILendFacet.sol";
import {ILeverageModule} from "../interfaces/internal/ILeverageModule.sol";
import {IPriceOracle} from "../interfaces/external/IPriceOracle.sol";

contract LeverageModule is
    ModuleBase,
    ILeverageModule,
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Invoke for IVault;
    using SafeERC20 for IERC20;
    modifier onlyOwner() {
        require(
            msg.sender == IOwnable(diamond).owner(),
            "LeverageModule:only owner"
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
        ILeverageFacet.LeveragePutOrder memory _order,
        ILeverageFacet.LeveragePutLenderData calldata _lenderData,
        ILeverageFacet.FeeData memory _feeData,
        bytes calldata _borrowerSignature,
        bytes calldata _lenderSignature
    ) internal view {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        require(
            !vaultFacet.getVaultLock(_order.optionHolder),
            "LeverageModule:optionHolder is locked"
        );
        require(
            !vaultFacet.getVaultLock(_order.optionWriter),
            "LeverageModule:optionWriter is locked"
        );
        require(
            vaultFacet.getVaultType(_order.optionHolder) == 9,
            "LeverageModule:optionHolder vaultType 9"
        );
        require(
            vaultFacet.getVaultType(_order.optionWriter) == 8,
            "LeverageModule:optionWriter vaultType 8"
        );
        require(
            _order.recipientAddress != address(0) &&
                _order.recipientAddress != _order.optionHolder,
            "LeverageModule:recipientAddress error"
        );
        require(
            _order.optionWriter != _order.optionHolder,
            "LeverageModule:optionWriter error"
        );
        require(
            _order.expirationDate > block.timestamp,
            "LeverageModule:invalid expirationDate"
        );
        require(
            _order.startDate < block.timestamp,
            "LeverageModule:invalid startDate"
        );
        IPlatformFacet platformFacet = IPlatformFacet(diamond);

        address eth = platformFacet.getEth();
        //verify underlyingAsset
        if (_order.underlyingAsset == eth) {
            require(
                _order.optionHolder.balance >= _order.underlyingAmount,
                "LeverageModule:optionHolder underlyingAsset not enough"
            );
            require(
                _order.optionWriter.balance >= _order.lockedUnderlyingAmount,
                "LeverageModule:optionWriter underlyingAsset lockedUnderlyingAmount not enough"
            );
        } else {
            require(
                IERC20(_order.underlyingAsset).balanceOf(_order.optionHolder) >=
                    _order.underlyingAmount,
                "LeverageModule:optionHolder underlyingAsset not enough"
            );
            require(
                IERC20(_order.underlyingAsset).balanceOf(_order.optionWriter) >=
                    _order.lockedUnderlyingAmount,
                "LeverageModule:optionWriter underlyingAsset lockedUnderlyingAmount not enough"
            );
        }
        require(
            _lenderData.maxUnderlyingAmount >= _order.underlyingAmount,
            "LeverageModule:underlyingAmount exceeds the maximum collateral amount"
        );
        require(
            _lenderData.minUnderlyingAmount <= _order.underlyingAmount,
            "LeverageModule:underlyingAmount below the minimum collateral amount"
        );
        //verify receiveAsset
        if (_order.receiveAsset == eth) {
            require(
                _order.optionWriter.balance >= _order.receiveAmount,
                "LeverageModule:optionWriter receiveAsset not enough"
            );
        } else {
            require(
                IERC20(_order.receiveAsset).balanceOf(_order.optionWriter) >=
                    _order.receiveAmount,
                "LeverageModule:optionWriter receiveAsset not enough"
            );
        }
        ILeverageFacet leverageFacet = ILeverageFacet(diamond);
        require(
            leverageFacet.getLeverageOrderByOrderID(_order.orderID).orderID ==
                0,
            "LeverageModule:orderID repeated"
        );
        require(
            !leverageFacet.getBorrowSignature(_borrowerSignature),
            "LeverageModule:_borrowerSignature repeated"
        );

        require(
            _order.receiveAsset == _lenderData.receiveAsset &&
                _order.underlyingAsset == _lenderData.underlyingAsset &&
                _order.expirationDate == _lenderData.expirationDate &&
                _order.startDate == _lenderData.startDate &&
                _order.stakeCount == _lenderData.stakeCount &&
                _order.hedgeRatio == _lenderData.hedgeRatio &&
                _order.interestRate == _lenderData.interestRate &&
                _order.platformFeeRate == _lenderData.platformFeeRate &&
                _order.tradeFeeRate == _lenderData.tradeFeeRate,
            "LeverageModule:data not same"
        );

        vaildBorrowerSign(_order.optionHolder, _order, _borrowerSignature);
        vaildLenderSign(_order.optionWriter, _lenderData, _lenderSignature);

        validSlippage(
            _order.lockedUnderlyingAmount,
            _feeData.lockedUnderlyingAmount,
            _order.slippage,
            _lenderData.slippage
        );
        validSlippage(
            _order.receiveAmount,
            _feeData.receiveAmount,
            _order.slippage,
            _lenderData.slippage
        );
        validSlippage(
            _order.positionValue,
            _feeData.positionValue,
            _order.slippage,
            _lenderData.slippage
        );
    }

    function getFee(
        uint input,
        uint hedgeRatio,
        uint interestRate,
        uint tradeRate,
        uint price,
        uint decimalA,
        uint decimalB
    ) public pure returns (uint, uint, uint) {
        uint usdcAmount = (input * price * 10 ** decimalB) /
            1 ether /
            10 ** decimalA;
        uint positionValue = (usdcAmount * hedgeRatio) / 1 ether;
        uint interest = (positionValue * interestRate) / 1 ether;
        uint tradeFeeAmount = (positionValue *
            (1 ether - interestRate) *
            tradeRate) /
            1 ether /
            1 ether;
        return (positionValue, interest, tradeFeeAmount);
    }

    function calculateFees(
        ILeverageFacet.LeveragePutOrder memory _order,
        uint price,
        uint priceRevert,
        IPlatformFacet platformFacet,
        address eth
    ) public view returns (ILeverageFacet.FeeData memory data) {
        uint decimalCollateralAsset = IERC20Metadata(
            _order.underlyingAsset == eth
                ? platformFacet.getWeth()
                : _order.underlyingAsset
        ).decimals();
        uint decimalBorrowAsset = IERC20Metadata(
            _order.receiveAsset == eth
                ? platformFacet.getWeth()
                : _order.receiveAsset
        ).decimals();
        data.underlyingAmount = _order.underlyingAmount;
        for (uint i = 0; i < _order.stakeCount; i++) {
            (uint positionValue, uint interest, uint tradeFeeAmount) = getFee(
                data.underlyingAmount,
                _order.hedgeRatio,
                _order.interestRate,
                _order.tradeFeeRate,
                price,
                decimalCollateralAsset,
                decimalBorrowAsset
            );
            data.underlyingAmount =
                ((positionValue - interest - tradeFeeAmount) *
                    priceRevert *
                    10 ** decimalCollateralAsset) /
                1 ether /
                10 ** decimalBorrowAsset;
            data.optionPremiumAmount += interest;
            data.tradeFeeAmount += i < _order.stakeCount - 1
                ? tradeFeeAmount
                : 0;
            data.receiveAmount = positionValue - interest;
            data.positionValue += positionValue;
            data.lockedUnderlyingAmount += i < _order.stakeCount - 1
                ? data.underlyingAmount
                : 0;
        }
        data.underlyingAmount = _order.underlyingAmount;
        return data;
    }

    function calculate(
        ILeverageFacet leverageFacet,
        ILeverageFacet.LeveragePutOrder memory _order,
        IPlatformFacet platformFacet,
        address eth
    ) public view returns (ILeverageFacet.FeeData memory) {
        uint256 price = IPriceOracle(leverageFacet.getPriceOracle()).getPrice(
            _order.underlyingAsset == eth
                ? platformFacet.getWeth()
                : _order.underlyingAsset,
            _order.receiveAsset == eth
                ? platformFacet.getWeth()
                : _order.receiveAsset
        );
        uint256 priceRevert = IPriceOracle(leverageFacet.getPriceOracle())
            .getPrice(
                _order.receiveAsset == eth
                    ? platformFacet.getWeth()
                    : _order.receiveAsset,
                _order.underlyingAsset == eth
                    ? platformFacet.getWeth()
                    : _order.underlyingAsset
            );

        return calculateFees(_order, price, priceRevert, platformFacet, eth);
    }

    function submitLeveragePutOrder(
        ILeverageFacet.LeveragePutOrder memory _leveragePutOrder,
        ILeverageFacet.LeveragePutLenderData calldata _lenderData,
        bytes calldata _borrowerSignature,
        bytes calldata _lenderSignature
    ) external nonReentrant onlyWhiteList {
        //verify data
        ILeverageFacet leverageFacet = ILeverageFacet(diamond);
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        address eth = platformFacet.getEth();
        ILeverageFacet.FeeData memory feeData = calculate(
            leverageFacet,
            _leveragePutOrder,
            platformFacet,
            eth
        );
        verifyPutOrder(
            _leveragePutOrder,
            _lenderData,
            feeData,
            _borrowerSignature,
            _lenderSignature
        );
        //storage data
        IVaultFacet vaultFacet = IVaultFacet(diamond);

        vaultFacet.setVaultLock(_leveragePutOrder.optionHolder, true);

        _leveragePutOrder.index = leverageFacet.getLeverageLenderPutOrderLength(
            _leveragePutOrder.optionWriter
        );
        leverageFacet.setLeverageBorrowerPutOrder(
            _leveragePutOrder.optionHolder,
            _leveragePutOrder
        );
        leverageFacet.setLeverageLenderPutOrder(
            _leveragePutOrder.optionWriter,
            _leveragePutOrder.optionHolder
        );

        if (_leveragePutOrder.receiveAsset == eth) {
            IVault(_leveragePutOrder.optionWriter).invokeTransferEth(
                _leveragePutOrder.recipientAddress,
                feeData.receiveAmount
            );
        } else {
            IVault(_leveragePutOrder.optionWriter).invokeTransfer(
                _leveragePutOrder.receiveAsset,
                _leveragePutOrder.recipientAddress,
                feeData.receiveAmount
            );
        }
        if (_leveragePutOrder.underlyingAsset == eth) {
            IVault(_leveragePutOrder.optionWriter).invokeTransferEth(
                _leveragePutOrder.optionHolder,
                feeData.lockedUnderlyingAmount
            );
        } else {
            IVault(_leveragePutOrder.optionWriter).invokeTransfer(
                _leveragePutOrder.underlyingAsset,
                _leveragePutOrder.optionHolder,
                feeData.lockedUnderlyingAmount
            );
        }
        leverageLendFee(_leveragePutOrder, feeData);
        leverageFacet.setLeverageFeeData(_leveragePutOrder.orderID, feeData);
        leverageFacet.setBorrowSignature(_borrowerSignature);
        leverageFacet.setLeverageOrderByOrderID(
            _leveragePutOrder.orderID,
            _leveragePutOrder
        );
        updatePosition(
            _leveragePutOrder.optionHolder,
            _leveragePutOrder.underlyingAsset,
            0
        );
        updatePosition(
            _leveragePutOrder.optionHolder,
            _leveragePutOrder.receiveAsset,
            0
        );
        updatePosition(
            _leveragePutOrder.optionWriter,
            _leveragePutOrder.underlyingAsset,
            0
        );
        updatePosition(
            _leveragePutOrder.optionWriter,
            _leveragePutOrder.receiveAsset,
            0
        );
        //set CurrentVaultModule
        setFuncBlackAndWhiteList(
            _leveragePutOrder.optionWriter,
            _leveragePutOrder.optionHolder,
            true
        );
        emit SubmitLeveragePutOrder(msg.sender, _leveragePutOrder, feeData);
    }

    function vaildBorrowerSign(
        address _signer,
        ILeverageFacet.LeveragePutOrder memory _data,
        bytes memory _signature
    ) public view {
        bytes32 infoTypeHash = keccak256(
            "LeveragePutOrder(uint256 orderID,uint256 startDate,uint256 expirationDate,address optionWriter,address optionHolder,address recipientAddress,address underlyingAsset,uint256 underlyingAmount,address receiveAsset,uint256 receiveAmount,uint256 lockedUnderlyingAmount,uint256 positionValue,uint256 stakeCount,uint256 slippage,uint256 hedgeRatio,uint256 platformFeeAmount,uint256 tradeFeeAmount,uint256 optionPremiumAmount,uint256 platformFeeRate,uint256 tradeFeeRate,uint256 interestRate,uint256 index)"
        );
        bytes32 _hashInfo = keccak256(abi.encode(infoTypeHash, _data));
        verifySignature(_signer, _hashInfo, _signature);
    }

    function vaildLenderSign(
        address _signer,
        ILeverageFacet.LeveragePutLenderData calldata _data,
        bytes memory _signature
    ) public view {
        bytes32 infoTypeHash = keccak256(
            "LeveragePutLenderData(address optionWriter,address underlyingAsset,address receiveAsset,uint256 minUnderlyingAmount,uint256 maxUnderlyingAmount,uint256 hedgeRatio,uint256 interestRate,uint256 slippage,uint256 stakeCount,uint256 startDate,uint256 expirationDate,uint256 platformFeeRate,uint256 tradeFeeRate)"
        );
        bytes32 _hashInfo = keccak256(abi.encode(infoTypeHash, _data));
        verifySignature(_signer, _hashInfo, _signature);
    }

    function verifySignature(
        address _signer,
        bytes32 _hash,
        bytes memory _signature
    ) public view {
        bytes32 domainHash = ILendFacet(diamond).getDomainHash();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainHash, _hash)
        );
        address signer = IVault(_signer).owner();
        address recoverAddress = ECDSA.recover(digest, _signature);
        require(recoverAddress == signer, "LeverageModule:signature error");
    }

    function validSlippage(
        uint amountA,
        uint amountB,
        uint borrrowSlippage,
        uint lenderSlippage
    ) public pure returns (bool) {
        uint slippage = borrrowSlippage < lenderSlippage
            ? borrrowSlippage
            : lenderSlippage;
        require(
            amountA <= (amountB * (1 ether + slippage)) / 1 ether,
            "LeverageModule: amountA < amountB"
        );
        require(
            amountA >= (amountB * (1 ether - slippage)) / 1 ether,
            "LeverageModule: amountA > amountB"
        );
        return true;
    }

    /*
    liquidate
    -debtor  borrow
    _type=true:liqudate underlyingAsset
    _type=false:liqudate receiveAsset
    -loaner optionWriter 
    liqudate underlyingAsset
    */
    function liquidateLeveragePutOrder(
        address _borrower,
        uint256 _type
    ) external payable nonReentrant {
        uint256 liquidateAmount;
        uint256 tradeFeeAmount;
        ILeverageFacet leverageFacet = ILeverageFacet(diamond);
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        ILeverageFacet.LeveragePutOrder
            memory _leveragePutOrder = ILeverageFacet(diamond)
                .getLeverageBorrowerPutOrder(_borrower);
        require(
            _leveragePutOrder.optionHolder != address(0),
            "LeverageModule:putOrder not exist"
        );
        leverageFacet.deleteLeverageBorrowerPutOrder(
            _leveragePutOrder.optionHolder
        );
        vaultFacet.setVaultLock(_leveragePutOrder.optionHolder, false);

        address eth = IPlatformFacet(diamond).getEth();
        address owner = IVault(_leveragePutOrder.optionHolder).owner();
        ILeverageFacet.FeeData memory feeData = ILeverageFacet(diamond)
            .getLeverageFeeData(_leveragePutOrder.orderID);
        if (
            owner == msg.sender ||
            (IPlatformFacet(diamond).getIsVault(msg.sender) &&
                IOwnable(msg.sender).owner() == owner)
        ) {
            // give up collateral
            if (_type == 1) {
                if (_leveragePutOrder.underlyingAsset == eth) {
                    IVault(_leveragePutOrder.optionHolder).invokeTransferEth(
                        _leveragePutOrder.optionWriter,
                        _leveragePutOrder.underlyingAmount +
                            feeData.lockedUnderlyingAmount
                    );
                    liquidateAmount =
                        _leveragePutOrder.underlyingAmount +
                        feeData.lockedUnderlyingAmount;
                } else {
                    //transfer token
                    // IVault(_leveragePutOrder.debtor).invokeTransfer(_leveragePutOrder.underlyingAsset,_leveragePutOrder.loaner,_leveragePutOrder.underlyingAmount);
                    uint256 balance = IERC20(_leveragePutOrder.underlyingAsset)
                        .balanceOf(_leveragePutOrder.optionHolder);
                    liquidateAmount = balance;
                    IVault(_leveragePutOrder.optionHolder).invokeTransfer(
                        _leveragePutOrder.underlyingAsset,
                        _leveragePutOrder.optionWriter,
                        liquidateAmount
                    );
                }
                updatePosition(
                    _leveragePutOrder.optionWriter,
                    _leveragePutOrder.underlyingAsset,
                    0
                );
                // pay all positionValue
            } else if (_type == 2) {
                liquidateAmount = feeData.positionValue;
                if (_leveragePutOrder.receiveAsset == eth) {
                    require(
                        msg.value >= liquidateAmount,
                        "LeverageModule: msg.vaule not enough"
                    );
                    _leveragePutOrder.optionWriter.call{value: liquidateAmount};
                } else {
                    IERC20(_leveragePutOrder.receiveAsset).safeTransferFrom(
                        _leveragePutOrder.recipientAddress,
                        _leveragePutOrder.optionWriter,
                        liquidateAmount
                    );
                }
                updatePosition(
                    _leveragePutOrder.optionWriter,
                    _leveragePutOrder.receiveAsset,
                    0
                );
            } else if (_type == 3) {
                // Revolving repay
                uint liquidatePrice;
                (
                    liquidateAmount,
                    tradeFeeAmount,
                    liquidatePrice
                ) = getliquidateAmount(
                    feeData,
                    _leveragePutOrder,
                    leverageFacet,
                    eth
                );
                handleRepayTransfer(
                    _leveragePutOrder,
                    liquidateAmount,
                    tradeFeeAmount,
                    eth
                );
                updatePosition(
                    _leveragePutOrder.optionWriter,
                    _leveragePutOrder.underlyingAsset,
                    0
                );
            }
        } else {
            require(
                _leveragePutOrder.expirationDate < block.timestamp,
                "LeverageModule:not expirationDate"
            );
            if (_leveragePutOrder.underlyingAsset == eth) {
                liquidateAmount =
                    _leveragePutOrder.underlyingAmount +
                    feeData.lockedUnderlyingAmount;
                IVault(_leveragePutOrder.optionHolder).invokeTransferEth(
                    _leveragePutOrder.optionWriter,
                    liquidateAmount
                );
            } else {
                //transfer token
                // IVault(_leveragePutOrder.debtor).invokeTransfer(_leveragePutOrder.underlyingAsset,_leveragePutOrder.loaner,_leveragePutOrder.underlyingAmount);
                uint256 balance = IERC20(_leveragePutOrder.underlyingAsset)
                    .balanceOf(_leveragePutOrder.optionHolder);
                liquidateAmount = balance;
                IVault(_leveragePutOrder.optionHolder).invokeTransfer(
                    _leveragePutOrder.underlyingAsset,
                    _leveragePutOrder.optionWriter,
                    liquidateAmount
                );
            }
            updatePosition(
                _leveragePutOrder.optionWriter,
                _leveragePutOrder.underlyingAsset,
                0
            );
        }

        leverageFacet.deleteLeverageLenderPutOrder(
            _leveragePutOrder.optionWriter,
            _leveragePutOrder.index
        );
        setFuncBlackAndWhiteList(
            _leveragePutOrder.optionWriter,
            _leveragePutOrder.optionHolder,
            false
        );
        leverageFacet.deleteLeverageFeeData(_leveragePutOrder.orderID);

        emit LiquidateLeveragePutOrder(
            msg.sender,
            _leveragePutOrder,
            _borrower,
            _type,
            liquidateAmount,
            tradeFeeAmount
        );
    }

    function handleRepayTransfer(
        ILeverageFacet.LeveragePutOrder memory _leveragePutOrder,
        uint liquidateAmount,
        uint tradeFeeAmount,
        address eth
    ) internal {
        address _lendFeePlatformRecipient = ILeverageFacet(diamond)
            .getleverageLendPlatformFeeRecipient();
        if (_leveragePutOrder.underlyingAsset == eth) {
            if (
                tradeFeeAmount != 0 && _lendFeePlatformRecipient != address(0)
            ) {
                IVault(_leveragePutOrder.optionHolder).invokeTransferEth(
                    _lendFeePlatformRecipient,
                    tradeFeeAmount
                );
            }
            IVault(_leveragePutOrder.optionHolder).invokeTransferEth(
                _leveragePutOrder.optionWriter,
                liquidateAmount
            );
        } else {
            if (
                tradeFeeAmount != 0 && _lendFeePlatformRecipient != address(0)
            ) {
                IVault(_leveragePutOrder.optionHolder).invokeTransfer(
                    _leveragePutOrder.underlyingAsset,
                    _lendFeePlatformRecipient,
                    tradeFeeAmount
                );
            }
            IVault(_leveragePutOrder.optionHolder).invokeTransfer(
                _leveragePutOrder.underlyingAsset,
                _leveragePutOrder.optionWriter,
                liquidateAmount
            );
        }
    }

    function leverageLendFee(
        ILeverageFacet.LeveragePutOrder memory _leveragePutOrder,
        ILeverageFacet.FeeData memory feeData
    ) internal {
        address _lendFeePlatformRecipient = ILeverageFacet(diamond)
            .getleverageLendPlatformFeeRecipient();
        require(
            _lendFeePlatformRecipient != address(0),
            "LeverageModule:_lendFeePlatformRecipient is zero "
        );
        if (
            _leveragePutOrder.receiveAsset == IPlatformFacet(diamond).getEth()
        ) {
            if (
                feeData.optionPremiumAmount != 0 &&
                _leveragePutOrder.platformFeeRate != 0
            ) {
                IVault(_leveragePutOrder.optionWriter).invokeTransferEth(
                    _lendFeePlatformRecipient,
                    (feeData.optionPremiumAmount *
                        _leveragePutOrder.platformFeeRate) / 1 ether
                );
            }

            if (feeData.tradeFeeAmount != 0) {
                IVault(_leveragePutOrder.optionWriter).invokeTransferEth(
                    _lendFeePlatformRecipient,
                    feeData.tradeFeeAmount
                );
            }
        } else {
            if (
                feeData.optionPremiumAmount != 0 &&
                _leveragePutOrder.platformFeeRate != 0
            ) {
                IVault(_leveragePutOrder.optionWriter).invokeTransfer(
                    _leveragePutOrder.receiveAsset,
                    _lendFeePlatformRecipient,
                    (feeData.optionPremiumAmount *
                        _leveragePutOrder.platformFeeRate) / 1 ether
                );
            }

            if (feeData.tradeFeeAmount != 0) {
                IVault(_leveragePutOrder.optionWriter).invokeTransfer(
                    _leveragePutOrder.receiveAsset,
                    _lendFeePlatformRecipient,
                    feeData.tradeFeeAmount
                );
            }
        }
    }

    function setFuncBlackAndWhiteList(
        address _blacker,
        address _whiter,
        bool _type
    ) internal {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        vaultFacet.setFuncBlackList(
            _blacker,
            bytes4(keccak256("setVaultType(address,uint256)")),
            _type
        );
        vaultFacet.setFuncWhiteList(
            _whiter,
            bytes4(
                keccak256(
                    "liquidateLeveragePutOrder(address,uint256,uint256,uint256)"
                )
            ),
            _type
        );
    }

    function setWhiteList(address _user, bool _type) external onlyOwner {
        ILeverageFacet(diamond).setWhiteList(_user, _type);
    }

    modifier onlyWhiteList() {
        require(
            ILeverageFacet(diamond).getWhiteList(msg.sender),
            "LeverageModule:msg.sender onlyWhiteList"
        );
        _;
    }

    function getliquidateAmount(
        ILeverageFacet.FeeData memory _data,
        ILeverageFacet.LeveragePutOrder memory _order,
        ILeverageFacet leverageFacet,
        address eth
    )
        public
        view
        returns (uint liquidateAmount, uint tradeFeeAmount, uint liquidatePrice)
    {
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        uint _collateralAssetDecimal = IERC20Metadata(
            _order.underlyingAsset == eth
                ? platformFacet.getWeth()
                : _order.underlyingAsset
        ).decimals();
        uint _borrowAssetDecimal = IERC20Metadata(
            _order.receiveAsset == eth
                ? platformFacet.getWeth()
                : _order.receiveAsset
        ).decimals();
        liquidatePrice = toDecimals(
            (_data.positionValue * (1 ether + _order.tradeFeeRate)) /
                (_order.underlyingAmount + _data.lockedUnderlyingAmount),
            _collateralAssetDecimal,
            _borrowAssetDecimal
        );
        uint nowPrice = IPriceOracle(leverageFacet.getPriceOracle()).getPrice(
            _order.underlyingAsset == eth
                ? platformFacet.getWeth()
                : _order.underlyingAsset,
            _order.receiveAsset == eth
                ? platformFacet.getWeth()
                : _order.receiveAsset
        );
        uint nowRevertPrice = IPriceOracle(leverageFacet.getPriceOracle())
            .getPrice(
                _order.receiveAsset == eth
                    ? platformFacet.getWeth()
                    : _order.receiveAsset,
                _order.underlyingAsset == eth
                    ? platformFacet.getWeth()
                    : _order.underlyingAsset
            );
        require(
            liquidatePrice <= nowPrice,
            "LeverageModule: no enough underlyingAsset to repay"
        );
        // 11 ether-  17920*0.0004*10**18
        uint repayAmount = toDecimals(
            _data.positionValue * nowRevertPrice,
            _collateralAssetDecimal,
            _borrowAssetDecimal + 18
        );
        uint fee = (repayAmount * _order.tradeFeeRate) / 1 ether;
        return (repayAmount - fee, fee, liquidatePrice);
    }

    function toDecimals(
        uint _input,
        uint _decimalsA,
        uint _decimalsB
    ) public pure returns (uint) {
        return
            _decimalsA >= _decimalsB
                ? _input * 10 ** (_decimalsA - _decimalsB)
                : _input / 10 ** (_decimalsB - _decimalsA);
    }
}
