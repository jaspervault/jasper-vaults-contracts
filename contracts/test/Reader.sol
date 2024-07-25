// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/internal/IReader.sol";

contract Reader is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    address public owner;
    modifier onlyOwner() {
        require(msg.sender ==owner, "Quoter:only owner");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        owner = msg.sender;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    mapping (address=>uint) public optionPremium;
    mapping (address=>Role) public readerRole;
    struct Profit{
        uint256  currentProfit ;
        uint256  currentAmount ;
    }
    mapping (address=>Profit) profits;
    enum Role {
        None,
        Writer
    }
    modifier onlyWriter() {
        require(readerRole[msg.sender] ==Role.Writer, "onlyWriter");
        _;
    }
    function setRole(address[] memory _userList, Role[] memory _roleList) public onlyOwner {
        require(_userList.length == _roleList.length, "_userList length mismatch _roleList length");
        for (uint i = 0; i < _userList.length; i++) {
            readerRole[_userList[i]] = _roleList[i];
        }
    }
    function setOptionPremium(address[] memory _userList, uint[] memory _premiumList) public onlyWriter {
        require(_userList.length == _premiumList.length, "_userList length mismatch _premiumList length");
        for (uint i = 0; i < _userList.length; i++) {
            optionPremium[_userList[i]] = _premiumList[i];
        }
    }
    function getOptionPremium(address[] memory _userList) public view returns(uint[] memory) {
        uint[] memory data =  new uint[](_userList.length);
         for (uint i = 0; i < _userList.length; i++) {
            data[i] =  optionPremium[_userList[i]];
        }
        return data;
    }

}