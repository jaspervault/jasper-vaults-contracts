// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


import "../lib/ModuleBase.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Invoke} from "../lib/Invoke.sol";
contract UtilsModule is ModuleBase, Initializable, UUPSUpgradeable {
	using SafeERC20 for IERC20;
    mapping(address=> address[])  public v2;
    mapping(address=> address[])  public v3;
	modifier onlyOwner() {
		require(
			msg.sender == depolyer,
			"UtilsModule:only owner"
		);
		_;
	}
	
	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}
	address public depolyer;
	function initialize(address _diamond) public initializer {
		__UUPSUpgradeable_init();
		diamond = _diamond; 
		depolyer = msg.sender;
	}
	
	function _authorizeUpgrade(
		address newImplementation
	) internal override onlyOwner {}


    function swapV2() external {

    }
    function Owner() public view returns(address){
		return IOwnable(diamond).owner();
    }
    function getDepolyer() public view returns(address){
		return depolyer;
    }
    function swapV3() external {
    }


}