// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;


interface IDelegatedManagerFactory {
    function jasperVaultType(address _jasperVault) external view returns(uint256);
    function acccount2setToken(address _account) external view returns(address);
    function setToken2account(address _jasperVault) external view returns(address);
}
