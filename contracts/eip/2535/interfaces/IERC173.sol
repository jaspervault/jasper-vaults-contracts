// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IERC173 {
    function owner() external view returns (address owner_);
    function transferOwnership(address _newOwner) external;
}
