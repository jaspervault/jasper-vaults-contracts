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

    mapping (address=>uint) public vaultAmountMap;
    mapping (address=>Role) public readerRole;
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

    function setVaultAmount(address _vault,uint256 _amount) external onlyWriter{
        vaultAmountMap[_vault] = _amount;
    }

    function getVaultAmount(address _vault) external view returns(uint256){
        return vaultAmountMap[_vault];
    }


}