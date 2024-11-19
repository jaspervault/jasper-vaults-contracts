// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacetV2} from "../interfaces/internal/IOptionFacetV2.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";

contract OptionFacetV2 is IOptionFacetV2 {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.OptionFacetV2.1.diamond.storage");
    struct OptionV2 {
        mapping (address => ManagedOptionsSettings[]) managedOptionsSettingList;
        mapping (uint64 orderId=> OptionExtra) optionExtra;
        uint256 nowOfferID;
    }
    function diamondStorage() internal pure returns (OptionV2 storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
    function getOfferID()public view returns(uint id){
         OptionV2 storage ds = diamondStorage();
         return ds.nowOfferID;
    }
    function nextOfferID()public returns(uint id){
        OptionV2 storage ds = diamondStorage();
        uint newOfferId = ds.nowOfferID +1;
        ds.nowOfferID = newOfferId;
        return newOfferId;
    }
    function setManagedOptionsSettings(ManagedOptionsSettings[] memory _set,address _vault,uint256[] memory _delIndex) external {
        OptionV2 storage ds = diamondStorage();
        for(uint i=0; i<_delIndex.length; i++) {
            uint setLen = ds.managedOptionsSettingList[_vault].length;
            ds.managedOptionsSettingList[_vault][_delIndex[i]]=ds.managedOptionsSettingList[_vault][setLen-1];
            ds.managedOptionsSettingList[_vault].pop();
        }
        for(uint i = 0; i < _set.length; i++){
            _set[i].offerID = nextOfferID();
            ds.managedOptionsSettingList[_vault].push(_set[i]);
        }
        emit SetManagedOptionsSettings(_set,_vault,_delIndex);
    }
    function getManagedOptionsSettings(address _vault) external view returns(IOptionFacetV2.ManagedOptionsSettings[] memory set) {
        OptionV2 storage ds = diamondStorage();
        return ds.managedOptionsSettingList[_vault];
    }
    function getManagedOptionsSettingsByIndex(address _vault,uint256 _index) external view returns(IOptionFacetV2.ManagedOptionsSettings memory set) {
        OptionV2 storage ds = diamondStorage();
        require(_index<ds.managedOptionsSettingList[_vault].length,"_index error");
        return ds.managedOptionsSettingList[_vault][_index];
    }
    function setOptionExtraData(uint64 _orderID, OptionExtra memory _data)external{
        OptionV2 storage ds = diamondStorage();
        require( ds.optionExtra[_orderID].productType==0,"repeat setOptionExtraData");
        ds.optionExtra[_orderID]=_data;
        emit SetOptionExtra(_orderID, _data);
    }
    function getOptionExtraData(uint64  _orderID)external view returns(OptionExtra memory _data){
        OptionV2 storage ds = diamondStorage();
        return ds.optionExtra[_orderID];
    }
}
