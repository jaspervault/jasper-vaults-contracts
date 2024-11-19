// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IReader {

    function getVaultProfit(address _vault) external view returns(uint256);
    function getVaultAmount(address _vault) external view returns(uint256);

}
