// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IOwnable{
    function owner() external view returns(address);
}

contract ProfitService is Initializable,OwnableUpgradeable, UUPSUpgradeable {

    uint256 public currentProfit ;
    uint256 public currentAmount ;
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    function initialize() initializer public {

        __UUPSUpgradeable_init();
         currentProfit = 0;
         currentAmount = 0;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function setLastProfix(uint256 _lastProfit) external{
        currentProfit = _lastProfit;
    }

    function getLastProfix() external view returns (uint256) {
        return currentProfit;
    }

    function setLastAmount(uint256 _lastAmount) external{
        currentAmount = _lastAmount;
    }

    function getLastAmount() external view returns (uint256) {
        return currentAmount;
    }

}