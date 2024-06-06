// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IOwnable{
    function owner() external view returns(address);
}

contract ERC20TOKEN is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    uint8 tokenDecimals ;
    function initialize(string memory tokenName, uint8  _decimals) initializer public {
        __ERC20_init(tokenName, tokenName);
        tokenDecimals = _decimals;
        __Ownable_init();
        __UUPSUpgradeable_init();
        _mint(msg.sender, 10000 ether * 10 ** decimals());
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
    function decimals() public view  override returns (uint8) {
        return tokenDecimals;
    }
 
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}