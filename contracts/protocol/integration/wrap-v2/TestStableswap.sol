/*
    Copyright 2021 Set Labs Inc.

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
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F

contract TestStableswap{
    address public lido;
    constructor(address _lido) public {
         lido=_lido;
    }
    //交换
    function exchange(int128 i,int128 j,uint256 dx, uint256 min_dy ) external payable returns (uint256){
            // 要给msg.sender 发送eth
            //要接收用户地址 steth
            // 把setToken的钱 转到当前地址
            //接收用户steth;
            IERC20(lido).transferFrom(msg.sender,address(this),dx);
            payable(msg.sender).transfer(dx);  
            return   dx;      
    }
    // 接收ether
    receive() external payable {
    }
    fallback() external payable {}
}

  