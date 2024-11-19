// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

interface IPriceOracle {

    /*
     * @param _assetOne         Address of first asset in pair
     * @param _assetTwo         Address of second asset in pair
     * @return                 one/two  Price of asset pair to 18 decimals of precision
     */
    function getPrice(
        address _assetOne,
        address _assetTwo
    ) external view returns (uint256);

   struct HistoryPrice{
      uint256 price;
      uint256 timestamp;
   }
    function getHistoryPrice(
        address _assetOne,
        uint256 _index,
        bytes[] calldata _data
    ) external returns (HistoryPrice[] memory historyPrices);

    struct RoundData {
      uint8 decimals;
      uint80 roundId;
      int256 answer;
      uint256 startedAt;
      uint256 updatedAt;
      uint80 answeredInRound;
   }
    function getUSDPrice(address _token) external view returns (uint256);
    function getUSDPriceSpecifyOracle(address _token, uint256 oracleIndex) external view returns (uint256);
    function getPriceSpecifyOracle(address _assetOne, address _assetTwo, uint256 oracleIndex) external view returns (uint256);
    function readByRoundID(address _masterToken, uint80 _roundId, uint _index)external view returns( RoundData memory );
}
