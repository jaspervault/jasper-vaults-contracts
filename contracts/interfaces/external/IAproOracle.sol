// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IAproOracle {
   function decimals() external view returns(uint8);
   function latestAnswer() external view returns (int256);
   function getRoundData(uint80 _roundId)external view returns (uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound);
   function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
   struct SummaryAproData{
      uint80 masterToekntRoundId;
      uint80 quotaTokenRoundId;
   }
   event ReadPrice(address masterToken, address quotaToken, uint256 masterPrice, uint256 quotaPrice);
}
