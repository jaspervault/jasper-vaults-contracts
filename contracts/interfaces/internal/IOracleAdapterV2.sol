// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {IPriceOracle} from "./IPriceOracle.sol";

interface IOracleAdapterV2 {
   struct Price {
      uint192 value;
      int8 decimal;
      uint32 observeAt;
      uint32 expireAt;
   }
   
   function readHistoryPrice(address _masterToken, bytes[] memory _data) external returns(IPriceOracle.HistoryPrice[] memory historyPrices);
   function setPrice(bytes[] memory _data)external;
}
