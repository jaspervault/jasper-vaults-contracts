// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IVaultFactory {
    function getAddress(
        address wallet,
        uint256 salt
    ) external view; 
}