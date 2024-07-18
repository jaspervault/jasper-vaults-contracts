// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionModuleV2} from "../internal/IOptionModuleV2.sol";

interface INFTFreeOptionPool {
    function getFreeAmount(IOptionModuleV2.ManagedOrder memory _info) external view returns (uint256 amount);
    function submitFreeAmount(IOptionModuleV2.ManagedOrder memory _info, uint256 amount) external view returns (bool ok);

}
