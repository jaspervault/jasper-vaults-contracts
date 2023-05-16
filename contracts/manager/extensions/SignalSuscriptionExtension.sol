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

import {IJasperVault} from "../../interfaces/IJasperVault.sol";
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
        address indexed _jasperVault,
        address indexed _delegatedManager
    );

    event SetFee(
        IJasperVault indexed _jasperVault,
        uint256 _followFee,
        uint256 _profitShareFee
    );

    // event SetSubscribeTarget(
    //      address indexed _jasperVault,
    //      address target
    // );
    event SetSubscribeStatus(IJasperVault indexed _jasperVault, uint256 status);

    event SetWhiteList(
        IJasperVault indexed _jasperVault,
        address user,
        bool status
    );

    /* ============ State Variables ============ */

    // Instance of SignalSuscriptionModule
    ISignalSuscriptionModule public immutable signalSuscriptionModule;

    //whiteList
    mapping(IJasperVault => mapping(address => bool)) public whiteList;

    mapping(IJasperVault => bool) public allowSubscribe;
    
    
    /* ============ Modifiers ============ */
    modifier ValidWhitelist(IJasperVault _jasperVault) {
        require(
            allowSubscribe[_jasperVault],
            "jasperVault not allow subscribe"
        );
        require(
            whiteList[_jasperVault][msg.sender],
            "user is not in the whitelist"
        );
        _;
    }

    /* ============ Constructor ============ */

    constructor(
        IManagerCore _managerCore,
        ISignalSuscriptionModule _signalSuscriptionModule
    ) public BaseGlobalExtension(_managerCore) {
        signalSuscriptionModule = _signalSuscriptionModule;
    }

    /* ============ External Functions ============ */
    function setWhiteListAndSubscribeStatus(
        IJasperVault _jasperVault,
        address[] memory _addList,
        address[] memory _delList,
        bool _status
    ) external onlyOperator(_jasperVault) {
        allowSubscribe[_jasperVault] = _status;
        for (uint256 i = 0; i < _addList.length; i++) {
            whiteList[_jasperVault][_addList[i]] = true;
            emit SetWhiteList(_jasperVault, _addList[i], true);
        }
        for (uint256 i = 0; i < _delList.length; i++) {
            whiteList[_jasperVault][_delList[i]] = false;
            emit SetWhiteList(_jasperVault, _delList[i], false);
        }
    }

    /**
     * ONLY OWNER: Initializes SignalSuscriptionModule on the JasperVault associated with the DelegatedManager.
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize the TradeModule for
     */
    function initializeModule(
        IDelegatedManager _delegatedManager
    ) external onlyOwnerAndValidManager(_delegatedManager) {
        require(
            _delegatedManager.isInitializedExtension(address(this)),
            "Extension must be initialized"
        );

        _initializeModule(_delegatedManager.jasperVault(), _delegatedManager);
    }

    /**
     * ONLY OWNER: Initializes TradeExtension to the DelegatedManager.
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize
     */
    function initializeExtension(
        IDelegatedManager _delegatedManager
    ) external onlyOwnerAndValidManager(_delegatedManager) {
        require(
            _delegatedManager.isPendingExtension(address(this)),
            "Extension must be pending"
        );

        IJasperVault jasperVault = _delegatedManager.jasperVault();

        _initializeExtension(jasperVault, _delegatedManager);

        emit SignalSuscriptionExtensionInitialized(
            address(jasperVault),
            address(_delegatedManager)
        );
    }

    /**
     * ONLY OWNER: Initializes TradeExtension to the DelegatedManager and TradeModule to the JasperVault
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize
     */
    function initializeModuleAndExtension(
        IDelegatedManager _delegatedManager
    ) external onlyOwnerAndValidManager(_delegatedManager) {
        require(
            _delegatedManager.isPendingExtension(address(this)),
            "Extension must be pending"
        );

        IJasperVault jasperVault = _delegatedManager.jasperVault();

        _initializeExtension(jasperVault, _delegatedManager);
        _initializeModule(jasperVault, _delegatedManager);

        emit SignalSuscriptionExtensionInitialized(
            address(jasperVault),
            address(_delegatedManager)
        );
    }

    /**
     * ONLY MANAGER: Remove an existing JasperVault and DelegatedManager tracked by the TradeExtension
     */
    function removeExtension() external override {
        IDelegatedManager delegatedManager = IDelegatedManager(msg.sender);
        IJasperVault jasperVault = delegatedManager.jasperVault();

        _removeExtension(jasperVault, delegatedManager);
    }

    function editSubscribeFee(
        IJasperVault _jasperVault,
        address _masterToken,
        uint256 _followFee,
        uint256 _profitShareFee
    ) external onlySettle(_jasperVault) onlyOperator(_jasperVault) {
        address[] memory followers = signalSuscriptionModule.get_followers(
            address(_jasperVault)
        );
        for (uint256 i = 0; i < followers.length; i++) {
            bytes memory callData = abi.encodeWithSelector(
                ISignalSuscriptionModule.unsubscribe.selector,
                followers[i],
                address(_jasperVault)
            );
            _invokeManager(
                _manager(IJasperVault(followers[i])),
                address(signalSuscriptionModule),
                callData
            );
            _manager(IJasperVault(followers[i])).setSubscribeStatus(2);
            emit SetSubscribeStatus(IJasperVault(followers[i]), 2);
        }
        _manager(_jasperVault).setBaseFeeAndToken(
            _masterToken,
            _followFee,
            _profitShareFee
        );
        emit SetFee(_jasperVault, _followFee, _profitShareFee);
    }

    function subscribe(
        IJasperVault _jasperVault,
        address target
    )
        external
        onlySettle(_jasperVault)
        ValidWhitelist(IJasperVault(target))
        onlyOperator(_jasperVault)
    {
        bytes memory callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.subscribe.selector,
            _jasperVault,
            target
        );
        _invokeManager(
            _manager(_jasperVault),
            address(signalSuscriptionModule),
            callData
        );
        _manager(_jasperVault).setSubscribeStatus(1);
        emit SetSubscribeStatus(_jasperVault, 1);
    }

    function unsubscribe(
        IJasperVault _jasperVault,
        address target
    )
        external
        onlySubscribed(_jasperVault)
        ValidWhitelist(IJasperVault(target))
        onlyOperator(_jasperVault)
    {
        bytes memory callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.unsubscribe.selector,
            _jasperVault,
            target
        );
        _invokeManager(
            _manager(_jasperVault),
            address(signalSuscriptionModule),
            callData
        );
        _manager(_jasperVault).setSubscribeStatus(2);
        emit SetSubscribeStatus(_jasperVault, 2);
    }

    function exectueFollowEnd(address _jasperVault) external {
        bytes memory callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.exectueFollowEnd.selector,
            _jasperVault
        );
        _invokeManager(
            _manager(IJasperVault(_jasperVault)),
            address(signalSuscriptionModule),
            callData
        );
    }

    /* ============ view Functions ============ */
    function getFollowers(
        address _jasperVault
    ) external view returns (address[] memory) {
        return signalSuscriptionModule.get_followers(_jasperVault);
    }

    function getExectueFollow(
        address _jasperVault
    ) external view returns (bool) {
        return signalSuscriptionModule.isExectueFollow(_jasperVault);
    }

    function warnLine() external view returns (uint256) {
        return signalSuscriptionModule.warningLine();
    }

    function unsubscribeLine() external view returns (uint256) {
        return signalSuscriptionModule.unsubscribeLine();
    }

    /* ============ Internal Functions ============ */

    /**
     * Internal function to initialize TradeModule on the JasperVault associated with the DelegatedManager.
     *
     * @param _jasperVault             Instance of the JasperVault corresponding to the DelegatedManager
     * @param _delegatedManager     Instance of the DelegatedManager to initialize the TradeModule for
     */
    function _initializeModule(
        IJasperVault _jasperVault,
        IDelegatedManager _delegatedManager
    ) internal {
        bytes memory callData = abi.encodeWithSignature(
            "initialize(address)",
            _jasperVault
        );
        _invokeManager(
            _delegatedManager,
            address(signalSuscriptionModule),
            callData
        );
    }
}
