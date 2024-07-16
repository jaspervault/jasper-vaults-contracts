// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionModule} from "../internal/IOptionModule.sol";

interface INFTFreeOptionPool {
    function getFreeAmount(IOptionModule.ManagedOrder memory _info) external view returns (uint256 amount);
    function submitFreeAmount(IOptionModule.ManagedOrder memory _info, uint256 amount) external view returns (bool ok);

}
