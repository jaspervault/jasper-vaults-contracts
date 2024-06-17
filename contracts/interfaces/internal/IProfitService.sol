// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IProfitService {

    function currentProfit() external view returns(uint256);
    
    function currentAmount() external view returns(uint256);

}
