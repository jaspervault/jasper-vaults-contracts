// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IReader {

    function getOptionProfit(address _user) external view returns(uint256);
    function getOptionAmount(address _user) external view returns(uint256);

}
