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
}
