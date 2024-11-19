// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../lib/ModuleBase.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {Invoke} from "../lib/Invoke.sol";
import {INonfungiblePositionManager} from "../interfaces/external/INonfungiblePositionManager.sol";

contract ProfitManager is  ModuleBase,Initializable,UUPSUpgradeable, ReentrancyGuardUpgradeable{
    using Invoke for IVault;
    receive() external payable {}
    address eth;
    modifier onlyOwner() {
        require( msg.sender == IOwnable(diamond).owner(),"ProfitManager:only owner");  
        _;
    }
    modifier onlyOperater() {
        require(operaterList[ msg.sender],"ProfitManager:only opreater");  
        _;
    }
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }



    function initialize(address _diamond, address _operater) public initializer {
        operaterList[_operater]=true;
        __UUPSUpgradeable_init();
        diamond = _diamond;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // 
    struct Profit{
        address token;
        uint amount;
    }
    mapping(address=>Profit[]) public profitWhiteList;

    mapping (address => bool) operaterList;

    function setOperater(address _operater, bool _status)public onlyOwner{
        operaterList[_operater] = _status;
    }
    function setETH(address _eth)public onlyOwner{
        eth = _eth;
    }
    function getProfitWhiteList(address _user)public view returns(Profit[] memory _fees){
        return profitWhiteList[_user];
    }
    function setProfitWhiteList(address _user,Profit[] memory _profitList)public onlyOperater{
        Profit[] storage userProfitList = profitWhiteList[_user];
        for (uint i;i<_profitList.length;i++){
            bool flag;
            for (uint k;k<userProfitList.length;k++){
                if (userProfitList[k].token==_profitList[i].token){
                    flag = true;
                    userProfitList[k].amount = _profitList[i].amount;
                    break;
                }
            }
            if (!flag){
                userProfitList.push(_profitList[i]);
            }
        }
  
    }
    function withDraw(Profit[] memory _profitList)public payable nonReentrant{
        require(profitWhiteList[msg.sender].length>0,"ProfitManager:no profig");
        Profit[] storage userProfitList = profitWhiteList[msg.sender];
         for (uint i;i<_profitList.length;i++){
            for (uint k;k<userProfitList.length;k++){
                if (userProfitList[k].token==_profitList[i].token){
                    require(userProfitList[k].amount >=_profitList[i].amount,"ProfitManager:amount error");
                    userProfitList[k].amount -= _profitList[i].amount;
                    if (_profitList[i].token==eth){
                        (bool success, ) =msg.sender.call{value:_profitList[i].amount}("");
                        require(success,"ProfitManager:eth transfer error");
                    }else{
                        require(IERC20(_profitList[i].token).transfer( msg.sender,_profitList[i].amount),"ProfitManager:transfer error");
                    }
                }
            }

        }
    }
}
