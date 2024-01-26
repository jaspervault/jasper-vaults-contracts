// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface ILendFacet {
    enum CollateralNftType {
        UnUsed,
        UniswapV3
    }

    struct PutOrder {
        uint256 orderID;
        address optionWriter;
        address optionHolder;
        address recipientAddress;
        /**
          if underlyingAssetType==0  underlyingAsset is Token
          if underlyingAssetType==1  underlyingAsset  is nft
         */
        address underlyingAsset;
        /**
          if underlyingAssetType==0  underlyingAmount is Token amount
          if underlyingAssetType==1  underlyingAsset  is liquidity
         */
        uint256 underlyingAmount;
        address receiveAsset;
        uint256 receiveMinAmount;
        uint256 receiveAmount;
        uint256 expirationDate;
        uint256 platformFeeAmount;
        uint256 index;
        uint256 optionPremiumAmount;
        uint256 underlyingAssetType;
        uint256 underlyingNftID;
    }
    struct CallOrder {
        uint256 orderID;
        address optionHolder;
        address optionWriter;
        address optionHolderWallet;
        address underlyingAsset;
        uint256 underlyingAmount;
        address optionPremiumAsset;
        uint256 optionPremiumAmount;
        uint256 optionPremiumMinAmount;
        uint256 xFeeAmount;
        uint256 strikeNotionalMinAmount;
        uint256 strikeNotionalAmount;
        uint256 expirationDate;
        uint256 platformFeeAmount;
        uint256 index;
        uint256 underlyingAssetType;
        uint256 underlyingNftID;
    }
    event SetCollateralNft(address _nft, CollateralNftType _type);
    event SetLendFeePlatformRecipient(address _recipient);
    event SetDomainHash(bytes32 _domainHash);

    function setBorrowerPutOrder(
        address _borrower,
        PutOrder memory _putOrder
    ) external;

    function deleteBorrowerPutOrder(address _borrower) external;

    function getBorrowerPutOrder(
        address _borrower
    ) external view returns (PutOrder memory);

    function setLenderPutOrder(address _lender, address _borrower) external;

    function getLenderPutOrder(
        address _lender
    ) external view returns (address[] memory);

    function getLenderPutOrderLength(
        address _lender
    ) external view returns (uint256);

    function deleteLenderPutOrder(address _lender, uint256 _index) external;

    function setBorrowerPutOrderNftInfo(
        address _borrower,
        uint256 _collateralNftId,
        uint256 _newLiquidity
    ) external;

    //----
    function setDomainHash(bytes32 _domainHash) external;

    function getDomainHash() external view returns (bytes32);

    function setLendFeePlatformRecipient(
        address _lendFeePlatformRecipient
    ) external;

    function getLendFeePlatformRecipient() external view returns (address);

    //-----
    function setLenderCallOrder(
        address _lender,
        CallOrder memory _callOrder
    ) external;

    function deleteLenderCallOrder(address _lender) external;

    function getLenderCallOrder(
        address _lender
    ) external view returns (CallOrder memory);

    function setBorrowerCallOrder(address _borrower, address _lender) external;

    function getBorrowerCallOrderLength(
        address _borrower
    ) external view returns (uint256);

    function getBorrowerCallOrder(
        address _borrower
    ) external view returns (address[] memory);

    function deleteLenderCallOrder(address _borrower, uint256 _index) external;

    function setLenderCallOrderNftInfo(
        address _lender,
        uint256 _collateralNftId,
        uint256 _newLiquidity
    ) external;

    //----
    function setCollateralNft(address _nft, CollateralNftType _type) external;

    function getCollateralNft(
        address _nft
    ) external view returns (CollateralNftType);
}
