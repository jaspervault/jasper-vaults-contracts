// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IOwnable} from "../../interfaces/internal/IOwnable.sol";
import {IOracleAdapter} from "../../interfaces/internal/IOracleAdapter.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
contract PythOracleAdapter is IOracleAdapter, Initializable, UUPSUpgradeable {
    address public diamond;
    address public pyth;
    mapping(address => mapping(address => bytes32)) public oralces;
    address public usdToken;
    event SetOralces(
        address[] _masterTokens,
        address[] _quoteTokens,
        bytes32[] _oracles
    );

    modifier onlyOwner() {
        require(msg.sender == IOwnable(diamond).owner(), "only owner");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _diamond,
        address _pyth,
        address _usdToken
    ) public initializer {
        diamond = _diamond;
        usdToken = _usdToken;
        pyth=_pyth;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setOralceList(
        address[] memory _masterTokens,
        address[] memory _quoteTokens,
        bytes32[] memory _oracles
    ) external onlyOwner {
        for (uint i; i < _quoteTokens.length; i++) {
           require(_quoteTokens[i] == usdToken, "ChainLinkOracleAdapter:quoteToken error"  );     
           oralces[_masterTokens[i]][_quoteTokens[i]] = _oracles[i];
        }
        emit SetOralces(_masterTokens,_quoteTokens,_oracles);
    }

    function read( address _masterToken, address _quoteToken ) external view returns (uint256) {

        if(_quoteToken ==usdToken){
            uint256 price=getPriceByBase(_masterToken,_quoteToken);
            if(price==0){
                price=getPriceByUsd(_masterToken,_quoteToken);
            }
            return price;
        }else{
            uint256 firstPrice=getPriceByBase(_masterToken,usdToken);
            if(firstPrice==0){
                firstPrice=getPriceByUsd(_masterToken,usdToken);
            }
            firstPrice = firstPrice/10**10;
            require(firstPrice!=0,"PythOracleAdapter Error:_masterToken token priceId Miss ");
            uint256 secondPrice=getPriceByBase(_quoteToken,usdToken);
            if(secondPrice==0){
                secondPrice=getPriceByUsd(_quoteToken,usdToken);
            }
            require(secondPrice!=0,"PythOracleAdapter Error:_quoteToken token priceId Miss ");
            secondPrice = secondPrice/10**10;
            return firstPrice*1 ether/secondPrice;
        }
    }
    function getPriceByBase(address _masterToken,address _quoteToken) internal view returns(uint256){
            bytes32 priceId=  oralces[_masterToken][_quoteToken];  
            if(priceId == bytes32(0)){
                 return 0;
            }
            return getPrice(priceId);
    }
    
    function getPrice(bytes32 priceId) internal view  returns(uint256){
         PythStructs.Price memory priceStruct;
         try  IPyth(pyth).getPrice(priceId) returns(PythStructs.Price memory ps){
            priceStruct=ps;
         }catch{
            return 0;
         }   
         uint256 price;
         if(priceStruct.price <=0){
              price=0;
         }else{
            uint64 tempPrice=uint64(priceStruct.price);
            price=uint256(tempPrice);
         }
         uint32 tempExpo=priceStruct.expo<0?uint32(-priceStruct.expo):uint32(priceStruct.expo);
         uint256 expo=uint256(tempExpo);
         price=price*10**(18-expo);
         return price;
    }
    function getPriceByUsd(address _masterToken,address _quoteToken) internal view returns(uint256){
           bytes32 masterId=oralces[_masterToken][usdToken];
           bytes32 quoteId=oralces[_quoteToken][usdToken];
           if(masterId == bytes32(0) || quoteId ==bytes32(0)){
               return 0;
           }
           uint256 masterPrice= getPrice(masterId);
           uint256 quotePrice= getPrice(quoteId);
           return masterPrice* 1 ether/quotePrice;
    }  
}
