// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacet} from "./IOptionFacet.sol";

interface IOptionService {
    enum LiquidateType {
        NotExercising,
        Exercising,
        ProfitTaking
    }
    event LiquidateOption(
        IOptionFacet.OrderType _orderType,
        uint64 _orderID,
        LiquidateType _type,
        uint256 _incomeAmount,
        uint256 _slippage
    );
    struct VerifyOrder {
        address holder;
        IOptionFacet.LiquidateMode liquidateMode;
        address writer;
        IOptionFacet.UnderlyingAssetType underlyingAssetType;
        address recipient;
        address underlyingAsset;
        address strikeAsset;
        uint256 underlyingAmount;
        uint256 strikeAmount;
        uint256 expirationDate;
        uint256 underlyingNftID;
        uint256 writerType;
        uint256 holderType;
    }

    struct LiquidateOrder{
        address holder;
        IOptionFacet.LiquidateMode liquidateMode;
        address writer;
        IOptionFacet.UnderlyingAssetType underlyingAssetType;
        address recipient;
        address underlyingAsset;
        address strikeAsset;
        uint256 underlyingAmount;
        uint256 strikeAmount;
        uint256 expirationDate;
        uint256 underlyingNftID;
    }

    function createPutOrder(
        IOptionFacet.PutOrder memory _putOrder
    ) external;
     function createCallOrder(
        IOptionFacet.CallOrder memory _callOrder
    ) external;
    function liquidateOption(
        IOptionFacet.OrderType _orderType,
        uint64 _orderID,
        LiquidateType _type,
        uint256 _incomeAmount,
        uint256 _slippage
    ) external payable;


    function getParts(address underlyingAsset,uint256 underlyingAmount,uint256 strikeAmount)  external view returns(uint256);

    function getEarningsAmount(
        address underlyingAsset, 
        uint256 underlyingAmount,
        address strikeAsset,
        uint256 strikeNotionalAmount
    ) external view returns (uint256);
}