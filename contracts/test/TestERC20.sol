// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TestERC20 is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    uint8 public tokenDecimals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string calldata _name,string calldata _symbol,uint256 _totalSupply,uint8 _tokenDecimals) initializer public {
        __ERC20_init(_name,_symbol);
        __Ownable_init();
        __UUPSUpgradeable_init();
         _mint(msg.sender, _totalSupply * 10 ** _tokenDecimals);
         tokenDecimals = _tokenDecimals;
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