// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IPythAdapter {
   struct PythData{
        bytes[]  updateData;
        bytes32[]  priceIds;
        uint64 minPublishTime;
        uint64 maxPublishTime;
   }
}
