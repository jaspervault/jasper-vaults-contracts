// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
// import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";

contract VaultMetaFacet  {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.VaultInfoFacet.diamond.storage");
    struct MetaData {
        string name;
    }
    struct VaultMeta {
        mapping (address => MetaData) metaInfo;
    }
    function diamondStorage() internal pure returns (VaultMeta storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
    
function setName(address _vault,string memory _name) external {
    VaultMeta storage ds = diamondStorage();
    ds.metaInfo[_vault].name= _name;
}
function getMeta(address _vault) external  view returns(MetaData memory data){
    VaultMeta storage ds = diamondStorage();
    return ds.metaInfo[_vault];
}
//    function setManagedOptionsSettings(ManagedOptionsSettings[] memory _set,address _vault,uint256[] memory _delIndex) external {
//         VaultMeta storage ds = diamondStorage();
//         for(uint i=0; i<_delIndex.length; i++) {
//             uint setLen = ds.managedOptionsSettingList[_vault].length;
//             ds.managedOptionsSettingList[_vault][_delIndex[i]]=ds.managedOptionsSettingList[_vault][setLen-1];
//             ds.managedOptionsSettingList[_vault].pop();
//         }
//         for(uint i = 0; i < _set.length; i++){
//             ds.managedOptionsSettingList[_vault].push(_set[i]);
//         }
//         emit SetManagedOptionsSettings(_set,_vault,_delIndex);
//     }
//     function getManagedOptionsSettings(address _vault) external view returns(IOptionFacetV2.ManagedOptionsSettings[] memory set) {
//         VaultMeta storage ds = diamondStorage();
//         return ds.managedOptionsSettingList[_vault];
//     }
//     function getManagedOptionsSettingsByIndex(address _vault,uint256 _index) external view returns(IOptionFacetV2.ManagedOptionsSettings memory set) {
//         VaultMeta storage ds = diamondStorage();
//         return ds.managedOptionsSettingList[_vault][_index];
//     }
}
