/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/
pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

import { IController } from "../interfaces/IController.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IDelegatedManagerFactory } from "../interfaces/IDelegatedManagerFactory.sol";
import {AddressArrayUtils} from "../lib/AddressArrayUtils.sol";
interface IOwnable{
    function owner() external returns(address);
}



contract SubscribeFeePool is Ownable,ReentrancyGuard{
    using SafeMath for uint256;
    using AddressArrayUtils for address[];
    IDelegatedManagerFactory public delegatedManagerFactory;
    IController public controller;
    struct DespositInfo{
        address[] compounts;
        uint256[] amounts;
    }
    mapping(address=>DespositInfo)  internal despositInfos;
    event Desposit(address _sender, address _to,uint256  _amount);
    event Witdraw(address _sender,address _to,uint256  _amount);
    event WitdrawJasperVault(address _jasperVault,address _sender,address _to,uint256  _amount);
    constructor(IController _controller,IDelegatedManagerFactory _delegatedManagerFactory) public {
        controller = _controller;
        delegatedManagerFactory=_delegatedManagerFactory;
    }
    function setSetting(IController _controller,IDelegatedManagerFactory _delegatedManagerFactory) external onlyOwner{
        controller = _controller;
        delegatedManagerFactory=_delegatedManagerFactory;
    }

    //desposit
    function desposit(address _token,address _to,uint256 _amount) external nonReentrant {
       IERC20(_token).transferFrom(msg.sender, address(this), _amount);
       address[] memory compounts=despositInfos[msg.sender].compounts;
       (uint256 index,bool exist)=compounts.indexOf(_token);
       if(exist){  
            uint256 balance=despositInfos[_to].amounts[index];
            despositInfos[_to].amounts[index]=balance.add(_amount); 

       }else{
           despositInfos[_to].compounts.push(_token);
           despositInfos[_to].amounts.push(_amount);
       }  
       emit Desposit(msg.sender,_to,_amount);
    }
    //withdraw   JasperVault
    function witdrawAndJasperVault(address _token,address _jasperVault,address _to,uint256 _amount) external nonReentrant{
        address account= delegatedManagerFactory.setToken2account(_jasperVault);
        address recipient=IOwnable(account).owner();
        require(recipient==msg.sender,"The caller is not the jasperVault owner");
        address[] memory compounts=despositInfos[msg.sender].compounts;
        (uint256 index,bool exist)=compounts.indexOf(_token);
        require(exist,"token is not exist");   
        uint256 balance=despositInfos[_jasperVault].amounts[index];
        despositInfos[_jasperVault].amounts[index]=balance.sub(_amount);  
        IERC20(_token).transfer(_to, _amount);
         emit WitdrawJasperVault(_jasperVault,msg.sender,_to,_amount);
    }
    // //withdraw
    function witdraw(address _token,address _to,uint256 _amount) external nonReentrant {
        address[] memory compounts=despositInfos[msg.sender].compounts;
        (uint256 index,bool exist)=compounts.indexOf(_token);
        require(exist,"token is not exist");   
        uint256 balance=despositInfos[msg.sender].amounts[index];
        despositInfos[msg.sender].amounts[index]=balance.sub(_amount);   
        IERC20(_token).transfer(_to, _amount);
        emit Witdraw(msg.sender,_to,_amount);
    }
    function getDespositInfo(address _user) external view returns(DespositInfo memory){
        return despositInfos[_user];
    }
}