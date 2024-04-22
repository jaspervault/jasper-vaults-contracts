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
        IOptionFacet.UnderlyingAssetType lockAssetType;
        address recipient;
        address lockAsset;
        address strikeAsset;
        uint256 lockAmount;
        uint256 strikeAmount;
        uint256 expirationDate;
        uint256 lockDate;
        uint256 underlyingNftID;
        uint256 writerType;
        uint256 holderType;
        uint256 quantity;
    }

    struct LiquidateOrder{
        address holder;
        IOptionFacet.LiquidateMode liquidateMode;
        address writer;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        address recipient;
        address lockAsset;
        address strikeAsset;
        uint256 lockAmount;
        uint256 strikeAmount;
        uint256 expirationDate;
        uint256 underlyingNftID;
        uint256 quantity;
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


    function getParts(uint256 quantity,uint256 strikeAmount)  external view returns(uint256);
    function setTotalPremium(address _vault,address _premiumAsset,uint _premiumFee) external ;

    function getEarningsAmount(
        address lockAsset, 
        uint256 lockAmount,
        address strikeAsset,
        uint256 strikeNotionalAmount,
        uint256 quantity
    ) external view returns (uint256);
}