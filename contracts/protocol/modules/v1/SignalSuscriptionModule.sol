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

pragma solidity ^0.6.10;
pragma experimental "ABIEncoderV2";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/SafeCast.sol";

import {IController} from "../../../interfaces/IController.sol";
import {Invoke} from "../../lib/Invoke.sol";
import {ISetToken} from "../../../interfaces/ISetToken.sol";
import {ModuleBase} from "../../lib/ModuleBase.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PreciseUnitMath} from "../../../lib/PreciseUnitMath.sol";
import {AddressArrayUtils} from "../../../lib/AddressArrayUtils.sol";

/**
 * @title TradeModule
 * @author Set Protocol
 *
 * Module that enables SetTokens to perform atomic trades using Decentralized Exchanges
 * such as 1inch or Kyber. Integrations mappings are stored on the IntegrationRegistry contract.
 */
contract SignalSuscriptionModule is ModuleBase, Ownable, ReentrancyGuard {
    using SafeCast for int256;
    using SafeMath for uint256;

    using Invoke for ISetToken;

    using PreciseUnitMath for uint256;
    using AddressArrayUtils for address[];

    mapping(address => address[]) public followers;
    mapping(address => bool) public isFollowing;
    mapping(address => address) public Signal_provider;
    mapping(address => bool) public allowed_Copytrading;

    /* ============ Constructor ============ */

    constructor(IController _controller) public ModuleBase(_controller) {}

    /* ============ External Functions ============ */

    /**
     * Initializes this module to the SetToken. Only callable by the SetToken's manager.
     *
     * @param _setToken                 Instance of the SetToken to initialize
     */
    function initialize(ISetToken _setToken)
        external
        onlyValidAndPendingSet(_setToken)
        onlySetManager(_setToken, msg.sender)
    {
        _setToken.initializeModule();
    }

    /**
     * Removes this module from the SetToken, via call by the SetToken. Left with empty logic
     * here because there are no check needed to verify removal.
     */
    function removeModule() external override {}

    function subscribe(ISetToken _setToken, address target)
        external
        nonReentrant
        onlyManagerAndValidSet(_setToken)
    {
        require(allowed_Copytrading[target], "Unable to subscribe this fund");
        require(
            !isFollowing[address(_setToken)],
            "Signal has been already subscribed"
        );
        followers[target].push(address(_setToken));
        isFollowing[address(_setToken)] = true;
        Signal_provider[address(_setToken)] = target;
    }

    function udpate_allowedCopytrading(
        ISetToken _setToken,
        bool can_copy_trading
    ) external onlyManagerAndValidSet(_setToken) {
        allowed_Copytrading[address(_setToken)] = can_copy_trading;
    }

    function unsubscribe(ISetToken _setToken, address target)
        external
        nonReentrant
        onlyManagerAndValidSet(_setToken)
    {
        require(
            isFollowing[address(_setToken)],
            "Signal has not been subscribed"
        );
        followers[target].removeStorage(address(_setToken));
        isFollowing[address(_setToken)] = false;
        delete Signal_provider[address(_setToken)];
    }

    function removeFollower(address target, address follower)
        external
        nonReentrant
        onlyOwner
    {
        require(isFollowing[follower], "Signal has not been subscribed");
        followers[target].removeStorage(follower);
        isFollowing[follower] = false;
        delete Signal_provider[follower];
    }

    function get_followers(address target)
        external
        view
        returns (address[] memory)
    {
        if (allowed_Copytrading[target]) {
            return followers[target];
        } else {
            return new address[](0);
        }
    }

    function get_signal_provider(ISetToken _setToken)
        external
        view
        returns (address)
    {
        return Signal_provider[address(_setToken)];
    }
}
