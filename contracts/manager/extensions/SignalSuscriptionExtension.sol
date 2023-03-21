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

import {ISetToken} from "@setprotocol/set-protocol-v2/contracts/interfaces/ISetToken.sol";
import {ISignalSuscriptionModule} from "../../interfaces/ISignalSuscriptionModule.sol";

import {BaseGlobalExtension} from "../lib/BaseGlobalExtension.sol";
import {IDelegatedManager} from "../interfaces/IDelegatedManager.sol";
import {IManagerCore} from "../interfaces/IManagerCore.sol";


/**
 * @title TradeExtension
 * @author Set Protocol
 *
 * Smart contract global extension which provides DelegatedManager privileged operator(s) the ability to trade on a DEX
 * and the owner the ability to restrict operator(s) permissions with an asset whitelist.
 */
contract SignalSuscriptionExtension is BaseGlobalExtension {
    /* ============ Events ============ */

    event SignalSuscriptionExtensionInitialized(
        address indexed _setToken,
        address indexed _delegatedManager
    );
    
    // event SetSubscribeTarget(
    //      address indexed _setToken,
    //      address target
    // );
    event SetSubscribeStatus(
         ISetToken indexed _setToken,
         bool status
    );

    event SetWhiteList(
         ISetToken indexed _setToken,
         address user,
         bool status
    );
    /* ============ Modifiers ============ */
    modifier ValidWhiteList(ISetToken _setToken){
        require(whiteList[_setToken][msg.sender],"user is not in the whitelist");        
        _;
    } 
    /* ============ State Variables ============ */

    // Instance of SignalSuscriptionModule
    ISignalSuscriptionModule public immutable signalSuscriptionModule;
    
    //setToken subscribe address
    // mapping(ISetToken=>address) public subscribeTargetList;
    
    //setToken subscribe  status
    // mapping(ISetToken=>bool) public subscribeStatusList;

    //whiteList
    mapping(ISetToken=>mapping(address=>bool)) public whiteList;
    /* ============ Constructor ============ */

    constructor(
        IManagerCore _managerCore,
        ISignalSuscriptionModule _signalSuscriptionModule
    ) public BaseGlobalExtension(_managerCore) {
        signalSuscriptionModule = _signalSuscriptionModule;
    }

    /* ============ External Functions ============ */
    function setWhiteList(ISetToken _setToken,address user,bool status) external  onlyOperator(_setToken) {
         require(!isContract(user),"user is not wallet address");
         bool _status=whiteList[_setToken][user];
         require(_status==status,"status set invalid");
         whiteList[_setToken][user]=status;
         emit SetWhiteList(_setToken,user,status);
    }


    /**
     * ONLY OWNER: Initializes SignalSuscriptionModule on the SetToken associated with the DelegatedManager.
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize the TradeModule for
     */
    function initializeModule(IDelegatedManager _delegatedManager)
        external
        onlyOwnerAndValidManager(_delegatedManager)
    {
        require(
            _delegatedManager.isInitializedExtension(address(this)),
            "Extension must be initialized"
        );

        _initializeModule(_delegatedManager.setToken(), _delegatedManager);
    }

    /**
     * ONLY OWNER: Initializes TradeExtension to the DelegatedManager.
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize
     */
    function initializeExtension(IDelegatedManager _delegatedManager)
        external
        onlyOwnerAndValidManager(_delegatedManager)
    {
        require(
            _delegatedManager.isPendingExtension(address(this)),
            "Extension must be pending"
        );

        ISetToken setToken = _delegatedManager.setToken();

        _initializeExtension(setToken, _delegatedManager);

        emit SignalSuscriptionExtensionInitialized(
            address(setToken),
            address(_delegatedManager)
        );
    }

    /**
     * ONLY OWNER: Initializes TradeExtension to the DelegatedManager and TradeModule to the SetToken
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize
     */
    function initializeModuleAndExtension(IDelegatedManager _delegatedManager)
        external
        onlyOwnerAndValidManager(_delegatedManager)
    {
        require(
            _delegatedManager.isPendingExtension(address(this)),
            "Extension must be pending"
        );

        ISetToken setToken = _delegatedManager.setToken();

        _initializeExtension(setToken, _delegatedManager);
        _initializeModule(setToken, _delegatedManager);

        emit SignalSuscriptionExtensionInitialized(
            address(setToken),
            address(_delegatedManager)
        );
    }

    /**
     * ONLY MANAGER: Remove an existing SetToken and DelegatedManager tracked by the TradeExtension
     */
    function removeExtension() external override {
        IDelegatedManager delegatedManager = IDelegatedManager(msg.sender);
        ISetToken setToken = delegatedManager.setToken();

        _removeExtension(setToken, delegatedManager);
    }

    function subscribe(ISetToken _setToken, address target)
        external
        onlyUnSubscribed(_setToken)
        ValidWhiteList(_setToken)
        onlyOperator(_setToken)
    {
        bytes memory callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.subscribe.selector,
            _setToken,
            target
        );
        _invokeManager(
            _manager(_setToken),
            address(signalSuscriptionModule),
            callData
        );
         _manager(_setToken).setSubscribeStatus(true);
        emit SetSubscribeStatus(_setToken,true);
    }

    function udpate_allowedCopytrading(
        ISetToken _setToken,
        bool can_copy_trading
    ) external onlyOperator(_setToken) {
        bytes memory callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.udpate_allowedCopytrading.selector,
            _setToken,
            can_copy_trading
        );
        _invokeManager(
            _manager(_setToken),
            address(signalSuscriptionModule),
            callData
        );
    }

    function unsubscribe(ISetToken _setToken, address target)
        external
        onlySubscribed(_setToken)
        ValidWhiteList(_setToken)
        onlyOperator(_setToken)
    {
        bytes memory callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.unsubscribe.selector,
            _setToken,
            target
        );
        _invokeManager(
            _manager(_setToken),
            address(signalSuscriptionModule),
            callData
        );
         _manager(_setToken).setSubscribeStatus(false);
        emit SetSubscribeStatus(_setToken,false);
    }

    /* ============ Internal Functions ============ */

    /**
     * Internal function to initialize TradeModule on the SetToken associated with the DelegatedManager.
     *
     * @param _setToken             Instance of the SetToken corresponding to the DelegatedManager
     * @param _delegatedManager     Instance of the DelegatedManager to initialize the TradeModule for
     */
    function _initializeModule(
        ISetToken _setToken,
        IDelegatedManager _delegatedManager
    ) internal {
        bytes memory callData = abi.encodeWithSignature(
            "initialize(address)",
            _setToken
        );
        _invokeManager(
            _delegatedManager,
            address(signalSuscriptionModule),
            callData
        );
    }

    function isContract(address addr) internal view returns(bool){
        uint size;assembly { size:=extcodesize(addr) } return size>0;
    }
}
