/*
    Copyright 2022 Set Labs Inc.

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

import {ISetToken} from "@setprotocol/set-protocol-v2/contracts/interfaces/ISetToken.sol";
import {INAVIssuanceModule} from "@setprotocol/set-protocol-v2/contracts/interfaces/INAVIssuanceModule.sol";
import {ISignalSuscriptionModule} from "../../interfaces/ISignalSuscriptionModule.sol";

import {StringArrayUtils} from "@setprotocol/set-protocol-v2/contracts/lib/StringArrayUtils.sol";

import {BaseGlobalExtension} from "../lib/BaseGlobalExtension.sol";
import {IDelegatedManager} from "../interfaces/IDelegatedManager.sol";
import {IManagerCore} from "../interfaces/IManagerCore.sol";
/**
 * @title CopyTradingExtension
 * @author Set Protocol
 *
 * Smart contract global extension which provides DelegatedManager operator(s) the ability to execute a batch of trades
 * on a DEX and the owner the ability to restrict operator(s) permissions with an asset whitelist.
 */
contract InstitutionServiceExtension is BaseGlobalExtension {
    using StringArrayUtils for string[];
    event InstitutionServiceExtensionInitialized(
        address indexed _setToken, // Address of the SetToken which had BatchTradeExtension initialized on their manager
        address indexed _delegatedManager // Address of the DelegatedManager which initialized the BatchTradeExtension
    );
    /* ============ State Variables ============ */

    // Instance of NAVIssuanceModule
    INAVIssuanceModule public immutable navIssuanceModule;

    ISignalSuscriptionModule public immutable signalSuscriptionModule;

    /* ============ Modifiers ============ */

    /**
     * Throws if the sender is not the ManagerCore contract owner
     */
    modifier onlyManagerCoreOwner() {
        require(
            msg.sender == managerCore.owner(),
            "Caller must be ManagerCore owner"
        );
        _;
    }

    /* ============ Constructor ============ */

    constructor(
        IManagerCore _managerCore,
        INAVIssuanceModule _navIssuanceModule,
        ISignalSuscriptionModule _signalSuscriptionModule
    ) public BaseGlobalExtension(_managerCore) {
        navIssuanceModule = _navIssuanceModule;
        signalSuscriptionModule = _signalSuscriptionModule;
    }

    /* ============ External Functions ============ */

    /**
     * ONLY OWNER: Initializes TradeModule on the SetToken associated with the DelegatedManager.
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize the TradeModule for
     */
    function initializeModule(IDelegatedManager _delegatedManager)
        external
        onlyOwnerAndValidManager(_delegatedManager)
    {
        _initializeModule(_delegatedManager.setToken(), _delegatedManager);
    }

    function initialize(
        ISetToken _setToken,
        address _target,
        address _reserveAsset,
        uint256 _reserveAssetQuantity,
        address _to
    ) external onlyOperator(_setToken) {
        bytes memory callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.subscribe.selector,
            _setToken,
            _target
        );
        _invokeManager(
            _manager(_setToken),
            address(signalSuscriptionModule),
            callData
        );
        navIssuanceModule.issue(
            _setToken,
            _reserveAsset,
            _reserveAssetQuantity,
            0,
            _to
        );
    }

    /**
     * ONLY OWNER: Initializes CopyTradingExtension to the DelegatedManager.
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize
     */
    function initializeExtension(IDelegatedManager _delegatedManager)
        external
        onlyOwnerAndValidManager(_delegatedManager)
    {
        ISetToken setToken = _delegatedManager.setToken();

        _initializeExtension(setToken, _delegatedManager);

        emit InstitutionServiceExtensionInitialized(
            address(setToken),
            address(_delegatedManager)
        );
    }

    /**
     * ONLY OWNER: Initializes CopyTradingExtension to the DelegatedManager and TradeModule to the SetToken
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize
     */
    function initializeModuleAndExtension(IDelegatedManager _delegatedManager)
        external
        onlyOwnerAndValidManager(_delegatedManager)
    {
        ISetToken setToken = _delegatedManager.setToken();

        _initializeExtension(setToken, _delegatedManager);
        _initializeModule(setToken, _delegatedManager);

        emit InstitutionServiceExtensionInitialized(
            address(setToken),
            address(_delegatedManager)
        );
    }

    /**
     * ONLY MANAGER: Remove an existing SetToken and DelegatedManager tracked by the CopyTradingExtension
     */
    function removeExtension() external override {
        IDelegatedManager delegatedManager = IDelegatedManager(msg.sender);
        ISetToken setToken = delegatedManager.setToken();

        _removeExtension(setToken, delegatedManager);
    }

    /* ============ Internal Functions ============ */

    function _initializeModule(
        ISetToken _setToken,
        IDelegatedManager _delegatedManager
    ) internal {}
}
