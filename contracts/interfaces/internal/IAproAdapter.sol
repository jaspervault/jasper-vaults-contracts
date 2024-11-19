// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
interface IAproAdapter {
   function readPrice(bytes32 feedId) external view ;
}
