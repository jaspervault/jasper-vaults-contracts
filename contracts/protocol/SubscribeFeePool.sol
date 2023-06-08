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

import {IController} from "../interfaces/IController.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IDelegatedManagerFactory} from "../interfaces/IDelegatedManagerFactory.sol";
import {AddressArrayUtils} from "../lib/AddressArrayUtils.sol";

interface IOwnable {
    function owner() external returns (address);
}

contract SubscribeFeePool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using AddressArrayUtils for address[];
    IDelegatedManagerFactory public delegatedManagerFactory;
    IController public controller;
    struct DepositInfo {
        address[] compounts;
        uint256[] amounts;
    }
    mapping(address => DepositInfo) internal DepositInfos;

    mapping(address => bool) public tokenWhiteList;

    event Deposit(address _sender, address _to, uint256 _amount);
    event Witdraw(address _sender, address _to, uint256 _amount);
    event WitdrawJasperVault(
        address _jasperVault,
        address _sender,
        address _to,
        uint256 _amount
    );
    event SetTokenWhiteList(address[] _addToken, address[] _delToken);
    modifier onlyTokenWhiteList(address _token) {
        require(tokenWhiteList[_token], "token not in tokenWhiteList");
        _;
    }

    constructor(
        IController _controller,
        IDelegatedManagerFactory _delegatedManagerFactory
    ) public {
        controller = _controller;
        delegatedManagerFactory = _delegatedManagerFactory;
    }

    function setSetting(
        IController _controller,
        IDelegatedManagerFactory _delegatedManagerFactory
    ) external onlyOwner {
        controller = _controller;
        delegatedManagerFactory = _delegatedManagerFactory;
    }

    function setTokenWhiteList(
        address[] calldata _addToken,
        address[] calldata _delToken
    ) external onlyOwner {
        for (uint256 i = 0; i < _addToken.length; i++) {
            tokenWhiteList[_addToken[i]] = true;
        }
        for (uint256 i = 0; i < _delToken.length; i++) {
            tokenWhiteList[_delToken[i]] = false;
        }
        emit SetTokenWhiteList(_addToken, _delToken);
    }

    //deposit
    function deposit(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyTokenWhiteList(_token) nonReentrant {
        if (_amount > 0) {
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
            address[] memory compounts = DepositInfos[_to].compounts;
            (uint256 index, bool exist) = compounts.indexOf(_token);
            if (exist) {
                uint256 balance = DepositInfos[_to].amounts[index];
                DepositInfos[_to].amounts[index] = balance.add(_amount);
            } else {
                DepositInfos[_to].compounts.push(_token);
                DepositInfos[_to].amounts.push(_amount);
            }
            emit Deposit(msg.sender, _to, _amount);
        }
    }

    //withdraw   JasperVault
    function witdrawAndJasperVault(
        address _token,
        address _jasperVault,
        address _to,
        uint256 _amount
    ) external nonReentrant {
        address account = delegatedManagerFactory.setToken2account(
            _jasperVault
        );
        // address recipient=IOwnable(account).owner();
        require(
            account == msg.sender,
            "The caller is not the jasperVault owner"
        );
        address[] memory compounts = DepositInfos[_jasperVault].compounts;
        (uint256 index, bool exist) = compounts.indexOf(_token);
        require(exist, "token is not exist");
        uint256 balance = DepositInfos[_jasperVault].amounts[index];
        require(balance >= _amount, "witdraw balance not enough");
        DepositInfos[_jasperVault].amounts[index] = balance.sub(_amount);
        IERC20(_token).transfer(_to, _amount);
        emit WitdrawJasperVault(_jasperVault, msg.sender, _to, _amount);
    }

    function witdrawAllAndJasperVault(
        address _jasperVault,
        address _to
    ) external nonReentrant {
        address account = delegatedManagerFactory.setToken2account(
            _jasperVault
        );
        // address recipient=IOwnable(account).owner();
        require(
            account == msg.sender,
            "The caller is not the jasperVault owner"
        );
        address[] memory compounts = DepositInfos[_jasperVault].compounts;
        uint256[] memory amounts = DepositInfos[_jasperVault].amounts;
        for (uint256 i = 0; i < compounts.length; i++) {
            if (amounts[i] > 0) {
                DepositInfos[_jasperVault].amounts[i] = 0;
                IERC20(compounts[i]).transfer(_to, amounts[i]);
                emit WitdrawJasperVault(
                    _jasperVault,
                    msg.sender,
                    _to,
                    amounts[i]
                );
            }
        }
    }

    // //withdraw
    function witdraw(
        address _token,
        address _to,
        uint256 _amount
    ) external nonReentrant {
        address[] memory compounts = DepositInfos[msg.sender].compounts;
        (uint256 index, bool exist) = compounts.indexOf(_token);

        require(exist, "token is not exist");
        uint256 balance = DepositInfos[msg.sender].amounts[index];
        require(balance >= _amount, "witdraw balance not enough");
        DepositInfos[msg.sender].amounts[index] = balance.sub(_amount);
        IERC20(_token).transfer(_to, _amount);
        emit Witdraw(msg.sender, _to, _amount);
    }

    function witdrawAll(address _to) external nonReentrant {
        address[] memory compounts = DepositInfos[msg.sender].compounts;
        uint256[] memory amounts = DepositInfos[msg.sender].amounts;
        for (uint256 i = 0; i < compounts.length; i++) {
            if (amounts[i] > 0) {
                DepositInfos[msg.sender].amounts[i] = 0;
                IERC20(compounts[i]).transfer(_to, amounts[i]);
                emit Witdraw(msg.sender, _to, amounts[i]);
            }
        }
    }

    function getDepositInfo(
        address _user
    ) external view returns (DepositInfo memory) {
        return DepositInfos[_user];
    }
}
