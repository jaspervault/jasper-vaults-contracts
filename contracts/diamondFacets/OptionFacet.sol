// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacet} from "../interfaces/internal/IOptionFacet.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";

contract OptionFacet is IOptionFacet {
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.OptionFacet.diamond.storage");

    struct Option {
        //---put---
        mapping(address => uint64[]) holderPuts; 
        mapping(address => uint64[]) writerPuts;
        mapping(uint64 => IOptionFacet.PutOrder) putOrders;
        //-----call-----
        mapping(address => uint64[]) holderCalls;
        mapping(address => uint64[]) writerCalls;
        mapping(uint64 => IOptionFacet.CallOrder) callOrders;
        //----other----
        mapping(address => CollateralNftType) nftType;
        uint64  orderId;
        bytes32 domain; 
        address feeRecipient;
        uint256 feeRate;
        mapping(address => uint256) totalPremium;
        //---safe verify----
        mapping(address =>mapping(OrderType=>mapping(address=>uint256[2])) ) sigatureInfo;
    }



    function diamondStorage() internal pure returns (Option storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
     
    }


    //---safe verify----






    function getDomain() external view returns (bytes32) {
        Option storage ds = diamondStorage();
        return ds.domain;
    }

    function setDomain(
        string memory _name,
        string memory _version,
        address _contract
    ) external {
        bytes32 DomainInfoTypeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 _domain = keccak256(
            abi.encode(
                DomainInfoTypeHash,
                keccak256(bytes(_name)),
                keccak256(bytes(_version)),
                block.chainid,
                _contract
            )
        );
        Option storage ds = diamondStorage();
        ds.domain = _domain;
        emit SetDomain(_name, _version, _contract, _domain);
    }

    //-----other-----
    function getOrderId() external view returns(uint64){
         Option storage ds = diamondStorage();
         return ds.orderId;
    } 
    function setOrderId() external {
         Option storage ds = diamondStorage();
         ds.orderId+=1;
         emit SetOrderId(ds.orderId);
    }

    function getFeeRecipient() external view returns (address) {
        Option storage ds = diamondStorage();
        return ds.feeRecipient;
    }

    function setFeeRecipient(address _feeRecipient) external {
        Option storage ds = diamondStorage();
        ds.feeRecipient = _feeRecipient;
        emit SetFeeRecipient(_feeRecipient);
    }

    function setFeeRate(uint256 _feeRate) external {
        Option storage ds = diamondStorage();
        ds.feeRate = _feeRate;
        emit SetFeeRate(_feeRate);
    }

    function getFeeRate() external view returns (uint256) {
        Option storage ds = diamondStorage();
        return ds.feeRate;
    }

    function setNftType(address _nft, CollateralNftType _type) external {
        Option storage ds = diamondStorage();
        ds.nftType[_nft] = _type;
        emit SetNftType(_nft, _type);
    }

    function getNftType(
        address _nft
    ) external view returns (CollateralNftType) {
        Option storage ds = diamondStorage();
        return ds.nftType[_nft];
    }

    //-----put------
    function addPutOrder(uint64 _orderId, PutOrder memory _putOrder) external {
        Option storage ds = diamondStorage();
        ds.putOrders[_orderId] = _putOrder;
        ds.holderPuts[_putOrder.holder].push(_orderId);
        ds.writerPuts[_putOrder.writer].push(_orderId);
        emit AddPutOrder(_orderId, _putOrder,IOwnable(_putOrder.holder).owner(),IOwnable(_putOrder.writer).owner());
    }

    function deletePutOrder(uint64 _orderId) external {
        Option storage ds = diamondStorage();
        PutOrder memory order=ds.putOrders[_orderId];
        delete ds.putOrders[_orderId];
        deleteStorageByOrderId(ds.holderPuts[order.writer], _orderId);
        deleteStorageByOrderId(ds.writerPuts[order.holder], _orderId);
        emit DeletePutOrder(_orderId,order);
    }

    function getPutOrder(
        uint64 _orderId
    ) external view returns (PutOrder memory) {
        Option storage ds = diamondStorage();
        return ds.putOrders[_orderId];
    }

    function getHolderPuts(
        address _holder
    ) external view returns (uint64[] memory) {
        Option storage ds = diamondStorage();
        return ds.holderPuts[_holder];
    }

    function getWriterPuts(
        address _writer
    ) external view returns (uint64[] memory) {
        Option storage ds = diamondStorage();
        return ds.writerPuts[_writer];
    }

    //----call-------
    function addCallOrder(
        uint64 _orderId,
        CallOrder memory _callOrder
    ) external {
        Option storage ds = diamondStorage();
        ds.callOrders[_orderId] = _callOrder;
        ds.holderCalls[_callOrder.holder].push(_orderId);
        ds.writerCalls[_callOrder.writer].push(_orderId);
        emit AddCallOrder(_orderId, _callOrder,IOwnable(_callOrder.holder).owner(),IOwnable(_callOrder.writer).owner());
    }

    function deleteCallOrder(uint64 _orderId) external {
        Option storage ds = diamondStorage();
        CallOrder memory order=ds.callOrders[_orderId];
        delete ds.callOrders[_orderId];
        deleteStorageByOrderId(ds.holderCalls[order.writer], _orderId);
        deleteStorageByOrderId(ds.writerCalls[order.holder], _orderId);
        emit DeleteCallOrder(_orderId,order);
    }

    function getCallOrder(
        uint64 _orderId
    ) external view returns (CallOrder memory) {
        Option storage ds = diamondStorage();
        return ds.callOrders[_orderId];
    }

    function getHolderCalls(
        address _holder
    ) external view returns (uint64[] memory) {
        Option storage ds = diamondStorage();
        return ds.holderCalls[_holder];
    }

    function getWriterCalls(
        address _writer
    ) external view returns (uint64[] memory) {
        Option storage ds = diamondStorage();
        return ds.writerCalls[_writer];
    }

    //-----util------
    function deleteStorageByOrderId(
        uint64[] storage _array,
        uint64 _orderId
    ) internal {
        for (uint i; i < _array.length; i++) {
            if (_array[i] == _orderId) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
            }
        }
    }

}
