// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {ILeverageFacet} from "./ILeverageFacet.sol";

interface ILeverageModule {
    event SubmitLeveragePutOrder(
        address indexed submitor,
        ILeverageFacet.LeveragePutOrder putOrder,
        ILeverageFacet.FeeData feeData
    );
    event LiquidateLeveragePutOrder(
        address indexed liquidator,
        ILeverageFacet.LeveragePutOrder putOrder,
        address _borrower,
        uint256 _type,
        uint256 liquidateAmount,
        uint256 tradeFeeAmount
    );

    function submitLeveragePutOrder(
        ILeverageFacet.LeveragePutOrder calldata _putOrder,
        ILeverageFacet.LeveragePutLenderData calldata _lenderData,
        bytes calldata _borrowerSignature,
        bytes calldata _lenderSignature
    ) external;

    function liquidateLeveragePutOrder(
        address _borrower,
        uint256 _type
    ) external payable;
}
