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

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {AddressArrayUtils} from "@setprotocol/set-protocol-v2/contracts/lib/AddressArrayUtils.sol";
import {IJasperVault} from "../../interfaces/IJasperVault.sol";
import {PreciseUnitMath} from "@setprotocol/set-protocol-v2/contracts/lib/PreciseUnitMath.sol";

import {IGlobalExtension} from "../interfaces/IGlobalExtension.sol";
import {MutualUpgradeV2} from "../lib/MutualUpgradeV2.sol";

/**
 * @title DelegatedManager
 * @author Set Protocol
 *
 * Smart contract manager that maintains permissions and JasperVault admin functionality via owner role. Owner
 * works alongside methodologist to ensure business agreements are kept. Owner is able to delegate maintenance
 * operations to operator(s). There can be more than one operator, however they have a global role so once
 * delegated to they can perform any operator delegated roles. The owner is able to set restrictions on what
 * operators can do in the form of asset whitelists. Operators cannot trade/wrap/claim/etc. an asset that is not
 * a part of the asset whitelist, hence they are a semi-trusted party. It is recommended that the owner address
 * be managed by a multi-sig or some form of permissioning system.
 */
contract DelegatedManager is Ownable, MutualUpgradeV2 {
    using Address for address;
    using AddressArrayUtils for address[];
    using SafeERC20 for IERC20;
    /* ============ Enums ============ */

    enum ExtensionState {
        NONE,
        PENDING,
        INITIALIZED
    }

    /* ============ Events ============ */

    event MethodologistChanged(address indexed _newMethodologist);

    event ExtensionAdded(address indexed _extension);

    event ExtensionRemoved(address indexed _extension);

    event ExtensionInitialized(address indexed _extension);

    event OperatorAdded(address indexed _operator);

    event OperatorRemoved(address indexed _operator);

    event AllowedAssetAdded(address indexed _asset);

    event AllowedAssetRemoved(address indexed _asset);

    event AllowedAdapterAdded(address indexed _adapter);

    event UseAssetAllowlistUpdated(bool _status);

    event OwnerFeeSplitUpdated(uint256 _newFeeSplit);

    event OwnerFeeRecipientUpdated(address indexed _newFeeRecipient);

    event AllowedAdapterRemoved(address indexed _adapter);

    /* ============ Modifiers ============ */

    /**
     * Throws if the sender is not the JasperVault methodologist
     */
    modifier onlyMethodologist() {
        require(msg.sender == methodologist, "Must be methodologist");
        _;
    }

    /**
     * Throws if the sender is not an initialized extension
     */
    modifier onlyExtension() {
        require(
            extensionAllowlist[msg.sender] == ExtensionState.INITIALIZED,
            "Must be initialized extension"
        );
        _;
    }

    /* ============ State Variables ============ */

    // Instance of JasperVault
    IJasperVault public immutable jasperVault;

    uint256 public subscribeStatus; //0 settle     1 subscribe  2 unsubscribe

    // Address of factory contract used to deploy contract
    address public immutable factory;

    // Mapping to check which ExtensionState a given extension is in
    mapping(address => ExtensionState) public extensionAllowlist;

    // Array of initialized extensions
    address[] internal extensions;

    // Mapping indicating if address is an approved operator
    mapping(address => bool) public operatorAllowlist;

    // List of approved operators
    address[] internal operators;

    // Mapping indicating if asset is approved to be traded for, wrapped into, claimed, etc.
    mapping(address => bool) public assetAllowlist;

    // List of allowed assets
    address[] internal allowedAssets;

    // Toggle if asset allow list is being enforced
    bool public useAssetAllowlist;

    mapping(address => bool) public useAsset_waitlist;

    mapping(address => uint256) public useAsset_timestamps;

    // Global owner fee split that can be referenced by Extensions
    uint256 public ownerFeeSplit;

    uint256 public managerFee;

    // Address owners portions of fees get sent to
    address public ownerFeeRecipient;

    // Address of methodologist which serves as providing methodology for the index and receives fee splits
    address public methodologist;

    mapping(address => bool) public adapterAllowlist;

    address[] public adapters;

    mapping(address => bool) public adapters_waitlist;

    mapping(address => uint256) public adapters_timestamps;

    uint256 public delay;

    /* ============ Constructor ============ */

    constructor(
        IJasperVault _jasperVault,
        address _factory,
        address _methodologist,
        address[] memory _extensions,
        address[] memory _operators,
        address[] memory _allowedAssets,
        address[] memory _adapters,
        bool _useAssetAllowlist
    ) public {
        jasperVault = _jasperVault;
        factory = _factory;
        methodologist = _methodologist;
        useAssetAllowlist = _useAssetAllowlist;

        emit UseAssetAllowlistUpdated(_useAssetAllowlist);

        _addExtensions(_extensions);
        _addOperators(_operators);
        _addAllowedAssets(_allowedAssets);
        _addAllowAdapters(_adapters);
        // 1 month
        delay = 2419200;
    }

    /* ============ ExternalFunctions ============ */

    function setSubscribeStatus(uint256 _status) external onlyExtension {
        require(subscribeStatus == _status, "status already set");
        subscribeStatus = _status;
    }

    /**
     * ONLY EXTENSION: Interact with a module registered on the JasperVault. In order to ensure JasperVault admin
     * functions can only be changed from this contract no calls to the JasperVault can originate from Extensions.
     * To transfer SetTokens use the `transferTokens` function.
     *
     * @param _module           Module to interact with
     * @param _data             Byte data of function to call in module
     */
    function interactManager(
        address _module,
        bytes calldata _data
    ) external onlyExtension {
        require(
            _module != address(jasperVault),
            "Extensions cannot call JasperVault"
        );
        if (adapters_timestamps[msg.sender] >= block.timestamp) {
            address[] memory _adapters = new address[](1);
            _adapters[0] = msg.sender;
            _addAllowAdapters(_adapters);
            delete adapters_timestamps[msg.sender];
            delete adapters_waitlist[msg.sender];
        }
        if (useAsset_timestamps[msg.sender] >= block.timestamp) {
            address[] memory _assets = new address[](1);
            _assets[0] = msg.sender;
            _addAllowedAssets(_assets);
            delete useAsset_timestamps[msg.sender];
            delete useAsset_waitlist[msg.sender];
        }
        // Invoke call to module, assume value will always be 0
        _module.functionCallWithValue(_data, 0);
    }

    /**
     * EXTENSION ONLY: Transfers _tokens held by the manager to _destination. Can be used to
     * distribute fees or recover anything sent here accidentally.
     *
     * @param _token           ERC20 token to send
     * @param _destination     Address receiving the tokens
     * @param _amount          Quantity of tokens to send
     */
    function transferTokens(
        address _token,
        address _destination,
        uint256 _amount
    ) external onlyExtension {
        IERC20(_token).safeTransfer(_destination, _amount);
    }

    /**
     * Initializes an added extension from PENDING to INITIALIZED state and adds to extension array. An
     * address can only enter a PENDING state if it is an enabled extension added by the manager. Only
     * callable by the extension itself, hence msg.sender is the subject of update.
     */
    function initializeExtension() external {
        require(
            extensionAllowlist[msg.sender] == ExtensionState.PENDING,
            "Extension must be pending"
        );

        extensionAllowlist[msg.sender] = ExtensionState.INITIALIZED;
        extensions.push(msg.sender);

        emit ExtensionInitialized(msg.sender);
    }

    /**
     * ONLY OWNER: Add new extension(s) that the DelegatedManager can call. Puts extensions into PENDING
     * state, each must be initialized in order to be used.
     *
     * @param _extensions           New extension(s) to add
     */
    function addExtensions(address[] memory _extensions) external onlyOwner {
        _addExtensions(_extensions);
    }

    /**
     * ONLY OWNER: Remove existing extension(s) tracked by the DelegatedManager. Removed extensions are
     * placed in NONE state.
     *
     * @param _extensions           Old extension to remove
     */
    function removeExtensions(address[] memory _extensions) external onlyOwner {
        for (uint256 i = 0; i < _extensions.length; i++) {
            address extension = _extensions[i];

            require(
                extensionAllowlist[extension] == ExtensionState.INITIALIZED,
                "Extension not initialized"
            );

            extensions.removeStorage(extension);

            extensionAllowlist[extension] = ExtensionState.NONE;

            IGlobalExtension(extension).removeExtension();

            emit ExtensionRemoved(extension);
        }
    }

    /**
     * ONLY OWNER: Add new operator(s) address(es)
     *
     * @param _operators           New operator(s) to add
     */
    function addOperators(address[] memory _operators) external onlyOwner {
        _addOperators(_operators);
    }

    /**
     * ONLY OWNER: Remove operator(s) from the allowlist
     *
     * @param _operators           New operator(s) to remove
     */
    function removeOperators(address[] memory _operators) external onlyOwner {
        for (uint256 i = 0; i < _operators.length; i++) {
            address operator = _operators[i];

            require(operatorAllowlist[operator], "Operator not already added");

            operators.removeStorage(operator);

            operatorAllowlist[operator] = false;

            emit OperatorRemoved(operator);
        }
    }

    /**
     * ONLY OWNER: Add new asset(s) that can be traded to, wrapped to, or claimed
     *
     * @param _assets           New asset(s) to add
     */
    function addAllowedAssets(address[] memory _assets) external onlyOwner {
        for (uint256 i = 0; i < _assets.length; i++) {
            address asset = _assets[i];
            useAsset_timestamps[asset] = block.timestamp + delay;
            useAsset_waitlist[asset] = true;
        }
    }

    function addAdapters(address[] memory _adapters) external onlyOwner {
        for (uint256 i = 0; i < _adapters.length; i++) {
            address adapter = _adapters[i];
            adapters_timestamps[adapter] = block.timestamp + delay;
            adapters_waitlist[adapter] = true;
        }
    }

    function removeAllowedAdapter(
        address[] memory _adapters
    ) external onlyOwner {
        for (uint256 i = 0; i < _adapters.length; i++) {
            address adapter = _adapters[i];

            require(adapterAllowlist[adapter], "Adapter is not in the list");

            adapters.removeStorage(adapter);

            adapterAllowlist[adapter] = false;

            emit AllowedAdapterRemoved(adapter);
        }
    }

    function remoeAllowedAssets(address[] memory _assets) external onlyOwner {
        for (uint256 i = 0; i < _assets.length; i++) {
            address asset = _assets[i];

            require(assetAllowlist[asset], "Asset is not in the list");

            allowedAssets.removeStorage(asset);

            assetAllowlist[asset] = false;

            emit AllowedAssetRemoved(asset);
        }
    }

    /**
     * MUTUAL UPGRADE: Update percent of fees that are sent to owner. Owner and Methodologist must each call this function to execute
     * the update. If Owner and Methodologist point to the same address, the update can be executed in a single call.
     *
     * @param _newFeeSplit           Percent in precise units (100% = 10**18) of fees that accrue to owner
     */
    function updateOwnerFeeSplit(
        uint256 _newFeeSplit
    ) external mutualUpgrade(owner(), methodologist) {
        require(
            _newFeeSplit <= PreciseUnitMath.preciseUnit(),
            "Invalid fee split"
        );

        ownerFeeSplit = _newFeeSplit;

        emit OwnerFeeSplitUpdated(_newFeeSplit);
    }

    function factoryReset(
        uint256 _newFeeSplit,
        uint256 _managerFees,
        uint256 _delay,
        address _masterToken
    ) external mutualUpgrade(owner(), methodologist) {
        require(
            _newFeeSplit <= PreciseUnitMath.preciseUnit(),
            "Invalid fee split"
        );

        ownerFeeSplit = _newFeeSplit;
        delay = _delay;
        jasperVault.setMasterToken(_masterToken);
        managerFee = _managerFees;
    }

    /**
     * ONLY OWNER: Update address owner receives fees at
     *
     * @param _newFeeRecipient           Address to send owner fees to
     */
    function updateOwnerFeeRecipient(
        address _newFeeRecipient
    ) external onlyOwner {
        require(_newFeeRecipient != address(0), "Null address passed");

        ownerFeeRecipient = _newFeeRecipient;

        emit OwnerFeeRecipientUpdated(_newFeeRecipient);
    }

    /**
     * ONLY METHODOLOGIST: Update the methodologist address
     *
     * @param _newMethodologist           New methodologist address
     */
    function setMethodologist(
        address _newMethodologist
    ) external onlyMethodologist {
        require(_newMethodologist != address(0), "Null address passed");

        methodologist = _newMethodologist;

        emit MethodologistChanged(_newMethodologist);
    }

    /**
     * ONLY OWNER: Update the JasperVault manager address.
     *
     * @param _newManager           New manager address
     */
    function setManager(address _newManager) external onlyOwner {
        require(_newManager != address(0), "Zero address not valid");
        require(extensions.length == 0, "Must remove all extensions");
        jasperVault.setManager(_newManager);
    }

    /**
     * ONLY OWNER: Add a new module to the JasperVault.
     *
     * @param _module           New module to add
     */
    function addModule(address _module) external onlyOwner {
        jasperVault.addModule(_module);
    }

    /**
     * ONLY OWNER: Remove a module from the JasperVault.
     *
     * @param _module           Module to remove
     */
    function removeModule(address _module) external onlyOwner {
        jasperVault.removeModule(_module);
    }

    /* ============ External View Functions ============ */

    function isAllowedAsset(address _asset) external view returns (bool) {
        if (useAsset_waitlist[_asset] == true) {
            if (useAsset_timestamps[_asset] > block.timestamp) {
                return true;
            }
        }
        return !useAssetAllowlist || assetAllowlist[_asset];
    }

    function isAllowedAdapter(address _adapter) external view returns (bool) {
        if (adapters_waitlist[_adapter] == true) {
            if (adapters_timestamps[_adapter] > block.timestamp) {
                return true;
            }
        }
        return adapterAllowlist[_adapter];
    }

    function isPendingExtension(
        address _extension
    ) external view returns (bool) {
        return extensionAllowlist[_extension] == ExtensionState.PENDING;
    }

    function isInitializedExtension(
        address _extension
    ) external view returns (bool) {
        return extensionAllowlist[_extension] == ExtensionState.INITIALIZED;
    }

    function getExtensions() external view returns (address[] memory) {
        return extensions;
    }

    function getOperators() external view returns (address[] memory) {
        return operators;
    }

    function getAllowedAssets() external view returns (address[] memory) {
        return allowedAssets;
    }

    /* ============ Internal Functions ============ */

    /**
     * Add extensions that the DelegatedManager can call.
     *
     * @param _extensions           New extension to add
     */
    function _addExtensions(address[] memory _extensions) internal {
        for (uint256 i = 0; i < _extensions.length; i++) {
            address extension = _extensions[i];

            require(
                extensionAllowlist[extension] == ExtensionState.NONE,
                "Extension already exists"
            );

            extensionAllowlist[extension] = ExtensionState.PENDING;

            emit ExtensionAdded(extension);
        }
    }

    /**
     * Add new operator(s) address(es)
     *
     * @param _operators           New operator to add
     */
    function _addOperators(address[] memory _operators) internal {
        for (uint256 i = 0; i < _operators.length; i++) {
            address operator = _operators[i];

            require(!operatorAllowlist[operator], "Operator already added");

            operators.push(operator);

            operatorAllowlist[operator] = true;

            emit OperatorAdded(operator);
        }
    }

    /**
     * Add new assets that can be traded to, wrapped to, or claimed
     *
     * @param _assets           New asset to add
     */
    function _addAllowedAssets(address[] memory _assets) internal {
        for (uint256 i = 0; i < _assets.length; i++) {
            address asset = _assets[i];
            if (!assetAllowlist[asset]) {
                allowedAssets.push(asset);
                assetAllowlist[asset] = true;
                emit AllowedAssetAdded(asset);
            }
        }
    }

    function _addAllowAdapters(address[] memory _adapters) internal {
        for (uint256 i = 0; i < _adapters.length; i++) {
            address adapter = _adapters[i];

            require(!adapterAllowlist[adapter], "Adapter already added");

            adapters.push(adapter);

            adapterAllowlist[adapter] = true;

            emit AllowedAdapterAdded(adapter);
        }
    }
}
