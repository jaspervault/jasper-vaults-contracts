// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Jasper1155NFT.sol";

contract JVTBTest is JVTB{

    function name() public pure override returns (string memory) {
        return "Jasper Vault Trading Benefits Test";
    }

    function symbol() public pure override returns (string memory) {
        return "JVTBTest";
    }
}