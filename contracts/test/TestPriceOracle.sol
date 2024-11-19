// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../eip/4337/interfaces/IEntryPoint.sol";
import "./VaultV2.sol";

import {IPriceOracle} from "../interfaces/internal/IPriceOracle.sol";


contract TestPriceOracle is Initializable, UUPSUpgradeable {
    event res(uint);
    function read(address p, address a, address b, uint i)public{
        emit res(IPriceOracle(p).getPriceSpecifyOracle(a,b,i));

    }
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
    ) public initializer {
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override  {}

}
