// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IOracleAdapter {
   function read(address _masterToken,address _quoteToken) external view returns(uint256);
}
