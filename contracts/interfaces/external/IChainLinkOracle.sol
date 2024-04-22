// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IChainLinkOracle {
    function decimals() external view returns(uint256);
    function latestAnswer() external view returns (uint256);
}
