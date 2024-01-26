// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILeverageFacet {
    struct LeveragePutOrder {
        uint256 orderID;
        uint256 startDate;
        uint256 expirationDate;
        address optionWriter;
        address optionHolder;
        address recipientAddress;
        address underlyingAsset;
        uint256 underlyingAmount;
        address receiveAsset;
        uint256 receiveAmount;
        uint256 lockedUnderlyingAmount;
        uint256 positionValue;
        uint256 stakeCount;
        uint256 slippage;
        uint256 hedgeRatio;
        uint256 platformFeeAmount;
        uint256 tradeFeeAmount;
        uint256 optionPremiumAmount;
        uint256 platformFeeRate;
        uint256 tradeFeeRate;
        uint256 interestRate;
        uint256 index;
    }
    struct LeveragePutLenderData {
        address optionWriter;
        address underlyingAsset;
        address receiveAsset;
        uint256 minUnderlyingAmount;
        uint256 maxUnderlyingAmount;
        uint256 hedgeRatio;
        uint256 interestRate;
        uint256 slippage;
        uint256 stakeCount;
        uint256 startDate;
        uint256 expirationDate;
        uint256 platformFeeRate;
        uint256 tradeFeeRate;
    }
    struct FeeData {
        uint underlyingAmount;
        uint optionPremiumAmount;
        uint tradeFeeAmount;
        uint receiveAmount;
        uint positionValue;
        uint lockedUnderlyingAmount;
    }
    event SetLendFeePlatformRecipient(address _recipient);

    function getPriceOracle() external view returns (address);

    function setWhiteList(address _user, bool _type) external;

    function getWhiteList(address _user) external view returns (bool);

    function setLeverageBorrowerPutOrder(
        address _borrower,
        LeveragePutOrder memory _putOrder
    ) external;

    function deleteLeverageBorrowerPutOrder(address _borrower) external;

    function getLeverageBorrowerPutOrder(
        address _borrower
    ) external view returns (LeveragePutOrder memory);

    function setLeverageLenderPutOrder(
        address _lender,
        address _borrower
    ) external;

    function getLeverageLenderPutOrder(
        address _lender
    ) external view returns (address[] memory);

    function getLeverageLenderPutOrderLength(
        address _lender
    ) external view returns (uint256);

    function deleteLeverageLenderPutOrder(
        address _lender,
        uint256 _index
    ) external;

    function setLeverageOrderByOrderID(
        uint256 orderID,
        LeveragePutOrder memory _order
    ) external;

    function getLeverageOrderByOrderID(
        uint256 orderID
    ) external view returns (LeveragePutOrder memory);

    function setLeverageFeeData(uint _orderID, FeeData memory _data) external;

    function deleteLeverageFeeData(uint _orderID) external;

    function getLeverageFeeData(
        uint _orderID
    ) external view returns (FeeData memory);

    function setBorrowSignature(bytes memory _sign) external;

    function getBorrowSignature(
        bytes memory _sign
    ) external view returns (bool);

    function setleverageLendPlatformFeeRecipient(address _addr) external;

    function getleverageLendPlatformFeeRecipient()
        external
        view
        returns (address);
}
