// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import {IOwnable} from "./interfaces/internal/IOwnable.sol";

import "hardhat/console.sol";

contract LPToken is
    ERC20PresetMinterPauserUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{

    address public diamond;
    modifier onlyOwner() {
        require(msg.sender == IOwnable(diamond).owner(), "only owner");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function __LPToken_init(
        address _diamond,
        string memory _name,
        string memory _symbol
    ) public initializer {
   
       initialize(_name,_symbol);
        __UUPSUpgradeable_init();
        //console.logBytes32(MINTER_ROLE);
        diamond = _diamond;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner{}


}
