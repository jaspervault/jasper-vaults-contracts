// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";

contract OptionFacetV2 is IOptionFacetV2 {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.OptionFacetV2.diamond.storage");
    struct OptionV2 {
        mapping (address => ManagedOptionsSettings[]) managedOptionsSettingList;
    }
    function diamondStorage() internal pure returns (OptionV2 storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setManagedOptionsSettings(ManagedOptionsSettings[] memory _set,address _vault) external {
        OptionV2 storage ds = diamondStorage();
        ManagedOptionsSettings[] memory oldSet = ds.managedOptionsSettingList[_vault];
        for(uint i = 0; i < oldSet.length; i++){
            ds.managedOptionsSettingList[_vault].pop();
        }
        for(uint i = 0; i < _set.length; i++){
            ds.managedOptionsSettingList[_vault].push(_set[i]);
        }
        emit SetManagedOptionsSettings(_set);
    }
    function getManagedOptionsSettings(address _vault) external view returns(IOptionFacetV2.ManagedOptionsSettings[] memory set) {
        OptionV2 storage ds = diamondStorage();
        return ds.managedOptionsSettingList[_vault];
    }
    function getManagedOptionsSettingsByIndex(address _vault,uint256 _index) external view returns(IOptionFacetV2.ManagedOptionsSettings memory set) {
        OptionV2 storage ds = diamondStorage();
        return ds.managedOptionsSettingList[_vault][_index];
    }
}
