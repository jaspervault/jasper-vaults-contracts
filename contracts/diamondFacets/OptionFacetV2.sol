// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";

contract OptionFacetV2 is IOptionFacetV2 {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.OptionFacetV2.diamond.storage");
    struct OptionV2 {
        mapping (address => ManagedOptionsSettings) managedOptionsSettings;
    }
    function diamondStorage() internal pure returns (OptionV2 storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
    function setManagedOptionsSettings(ManagedOptionsSettings memory _set) external {
        OptionV2 storage ds = diamondStorage();
        ds.managedOptionsSettings[_set.writer] = _set;
        emit SetManagedOptionsSettings(_set);
    }
    function getManagedOptionsSettings(address _vault) external view returns(IOptionFacetV2.ManagedOptionsSettings memory set) {
        OptionV2 storage ds = diamondStorage();
        return ds.managedOptionsSettings[_vault];
    }
}
