// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IAproOracleV2 {
   struct Price {
        uint192 value;
        int8 decimal;
        uint32 observeAt;
        uint32 expireAt;
   }
   struct Asset {
      address assetAddress;
      uint256 amount;
   }
   function verifyReportWithWrapNativeToken(bytes calldata payload) external returns(bytes32, uint32, uint192);
   function getValidTimePeriod() external view returns (uint256 validTimePeriod);
   function updateReport(bytes calldata report) external;
   function getPrice(
        bytes32 id
   ) external view returns (Price memory price);
   function getPriceUnsafe(
        bytes32 id
   ) external view returns (Price memory price);
   function getPriceNoOlderThan(
        bytes32 id,
        uint age
   ) external view returns (Price memory price);
   function getFeeAndReward(
        address subscriber,
        bytes memory unverifiedReport,
        address quoteAddress
    ) external returns (Asset memory, Asset memory, uint256);
   event ReadPrice(address masterToken, address quotaToken, uint256 masterPrice, uint256 quotaPrice);
}
