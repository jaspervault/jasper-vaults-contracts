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

import {IJasperVault} from "../../interfaces/IJasperVault.sol";
import {IWETH} from "@setprotocol/set-protocol-v2/contracts/interfaces/external/IWETH.sol";
import {ILeverageModule} from "../../interfaces/ILeverageModule.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseGlobalExtension} from "../lib/BaseGlobalExtension.sol";
import {IDelegatedManager} from "../interfaces/IDelegatedManager.sol";
import {IManagerCore} from "../interfaces/IManagerCore.sol";

import {ISignalSuscriptionModule} from "../../interfaces/ISignalSuscriptionModule.sol";

/**
 * @title WrapExtension
 * @author Set Protocol
 *

 */
contract LeverageExtension is BaseGlobalExtension {
    /* ============ Events ============ */

    event LeverageExtensionInitialized(
        address indexed _jasperVault,
        address indexed _delegatedManager
    );
    event InvokeFail(
        address indexed _manage,
        address _leverageModule,
        string _reason,
        bytes _callData
    );

    /* ============ State Variables ============ */

    // Instance of LeverageModule
    ILeverageModule public immutable leverageModule;
    ISignalSuscriptionModule public immutable signalSuscriptionModule;

    /* ============ Constructor ============ */

    /**
     * Instantiate with ManagerCore address and LeverageModule address.
     *
     * @param _managerCore              Address of ManagerCore contract
     * @param _leverageModule               Address of leverageModule contract
     */
    constructor(
        IManagerCore _managerCore,
        ILeverageModule _leverageModule,
        ISignalSuscriptionModule _signalSuscriptionModule
    ) public BaseGlobalExtension(_managerCore) {
        leverageModule = _leverageModule;
        signalSuscriptionModule = _signalSuscriptionModule;
    }

    /* ============ External Functions ============ */

    /**
     * ONLY OWNER: Initializes LeverageModule on the JasperVault associated with the DelegatedManager.
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize the LeverageModule for
     */
    function initializeModule(
        IDelegatedManager _delegatedManager,
        IERC20[] memory _collateralAssets,
        IERC20[] memory _borrowAssets
    ) external onlyOwnerAndValidManager(_delegatedManager) {
        _initializeModule(
            _delegatedManager.jasperVault(),
            _delegatedManager,
            _collateralAssets,
            _borrowAssets
        );
    }

    /**
     * ONLY OWNER: Initializes WrapExtension to the DelegatedManager.
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize
     */
    function initializeExtension(
        IDelegatedManager _delegatedManager
    ) external onlyOwnerAndValidManager(_delegatedManager) {
        IJasperVault jasperVault = _delegatedManager.jasperVault();

        _initializeExtension(jasperVault, _delegatedManager);

        emit LeverageExtensionInitialized(
            address(jasperVault),
            address(_delegatedManager)
        );
    }

    /**
     * ONLY OWNER: Initializes WrapExtension to the DelegatedManager and TradeModule to the JasperVault
     *
     * @param _delegatedManager     Instance of the DelegatedManager to initialize
     */
    function initializeModuleAndExtension(
        IDelegatedManager _delegatedManager,
        IERC20[] memory _collateralAssets,
        IERC20[] memory _borrowAssets
    ) external onlyOwnerAndValidManager(_delegatedManager) {
        IJasperVault jasperVault = _delegatedManager.jasperVault();

        _initializeExtension(jasperVault, _delegatedManager);
        _initializeModule(
            jasperVault,
            _delegatedManager,
            _collateralAssets,
            _borrowAssets
        );

        emit LeverageExtensionInitialized(
            address(jasperVault),
            address(_delegatedManager)
        );
    }

    /**
     * ONLY MANAGER: Remove an existing JasperVault and DelegatedManager tracked by the WrapExtension
     */
    function removeExtension() external override {
        IDelegatedManager delegatedManager = IDelegatedManager(msg.sender);
        IJasperVault jasperVault = delegatedManager.jasperVault();

        _removeExtension(jasperVault, delegatedManager);
    }

    function lever(
        IJasperVault _jasperVault,
        IERC20 _borrowAsset,
        IERC20 _collateralAsset,
        uint256 _borrowQuantityUnits,
        uint256 _minReceiveQuantityUnits,
        string memory _tradeAdapterName,
        bytes memory _tradeData
    )
        external
        onlySettle(_jasperVault)
        onlyOperator(_jasperVault)
        ValidAdapter(_jasperVault, address(leverageModule), _tradeAdapterName)
    {
        bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.lever.selector,
            _jasperVault,
            _borrowAsset,
            _collateralAsset,
            _borrowQuantityUnits,
            _minReceiveQuantityUnits,
            _tradeAdapterName,
            _tradeData
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
    }

    function delever(
        IJasperVault _jasperVault,
        IERC20 _collateralAsset,
        IERC20 _repayAsset,
        uint256 _redeemQuantityUnits,
        uint256 _minRepayQuantityUnits,
        string memory _tradeAdapterName,
        bytes memory _tradeData
    )
        external
        onlySettle(_jasperVault)
        onlyOperator(_jasperVault)
        ValidAdapter(_jasperVault, address(leverageModule), _tradeAdapterName)
    {
        bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.delever.selector,
            _jasperVault,
            _collateralAsset,
            _repayAsset,
            _redeemQuantityUnits,
            _minRepayQuantityUnits,
            _tradeAdapterName,
            _tradeData
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
    }

    function deleverToZeroBorrowBalance(
        IJasperVault _jasperVault,
        IERC20 _collateralAsset,
        IERC20 _repayAsset,
        uint256 _redeemQuantityUnits,
        string memory _tradeAdapterName,
        bytes memory _tradeData
    )
        external
        onlySettle(_jasperVault)
        onlyOperator(_jasperVault)
        ValidAdapter(_jasperVault, address(leverageModule), _tradeAdapterName)
    {
        bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.deleverToZeroBorrowBalance.selector,
            _jasperVault,
            _collateralAsset,
            _repayAsset,
            _redeemQuantityUnits,
            _tradeAdapterName,
            _tradeData
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
    }

    function leverFollowers(
        IJasperVault _jasperVault,
        IERC20 _borrowAsset,
        IERC20 _collateralAsset,
        uint256 _borrowQuantityUnits,
        uint256 _minReceiveQuantityUnits,
        string memory _tradeAdapterName,
        bytes memory _tradeData
    )
        external
        onlySettle(_jasperVault)
        onlyOperator(_jasperVault)
        ValidAdapter(_jasperVault, address(leverageModule), _tradeAdapterName)
    {

      
         bytes memory  callData = abi.encodeWithSelector(
            ILeverageModule.lever.selector,
            _jasperVault,
            _borrowAsset,
            _collateralAsset,
            _borrowQuantityUnits,
            _minReceiveQuantityUnits,
            _tradeAdapterName,
            _tradeData
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
       _executeFollower(ILeverageModule.lever.selector,_jasperVault,_borrowAsset,_collateralAsset,_borrowQuantityUnits,_minReceiveQuantityUnits,_tradeAdapterName,_tradeData);     

        callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.exectueFollowStart.selector,
            address(_jasperVault)
        );
        _invokeManager(_manager(_jasperVault), address(signalSuscriptionModule), callData);
    }


    function deleverFollowers(
        IJasperVault _jasperVault,
        IERC20 _collateralAsset,
        IERC20 _repayAsset,
        uint256 _redeemQuantityUnits,
        uint256 _minRepayQuantityUnits,
        string memory _tradeAdapterName,
        bytes memory _tradeData
    )
        external
        onlySettle(_jasperVault)
        onlyOperator(_jasperVault)
        ValidAdapter(_jasperVault, address(leverageModule), _tradeAdapterName)
    {
        bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.delever.selector,
            _jasperVault,
            _collateralAsset,
            _repayAsset,
            _redeemQuantityUnits,
            _minRepayQuantityUnits,
            _tradeAdapterName,
            _tradeData
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
        _executeFollower(ILeverageModule.delever.selector,_jasperVault,_collateralAsset,_repayAsset,_redeemQuantityUnits,_minRepayQuantityUnits,_tradeAdapterName,_tradeData);
        callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.exectueFollowStart.selector,
            address(_jasperVault)
        );
        _invokeManager(_manager(_jasperVault), address(signalSuscriptionModule), callData);
    }

    function _executeFollower(
        bytes4  selector,
        IJasperVault _jasperVault,
        IERC20 _assetsOne,
        IERC20 _assetsTwo,
        uint256 _quantityUnits,
        uint256 _minQuantityUnits,
        string memory _tradeAdapterName,
        bytes memory _tradeData
    ) internal {
           address[] memory followers = signalSuscriptionModule.get_followers(address(_jasperVault));           
            for (uint256 i = 0; i < followers.length; i++) {
                bytes memory callData = abi.encodeWithSelector(        
                    selector,
                    IJasperVault(followers[i]),
                    _assetsOne,
                    _assetsTwo,
                    _quantityUnits,
                    _minQuantityUnits,
                    _tradeAdapterName,
                    _tradeData
                );
                _execute(
                    _manager(IJasperVault(followers[i])),
                    address(leverageModule),
                    callData
                );
            }
     }


    function deleverToZeroBorrowBalanceFollowers(
        IJasperVault _jasperVault,
        IERC20 _collateralAsset,
        IERC20 _repayAsset,
        uint256 _redeemQuantityUnits,
        string memory _tradeAdapterName,
        bytes memory _tradeData
    )
        external
        onlySettle(_jasperVault)
        onlyOperator(_jasperVault)
        ValidAdapter(_jasperVault, address(leverageModule), _tradeAdapterName)
    {

       bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.deleverToZeroBorrowBalance.selector,
            _jasperVault,
            _collateralAsset,
            _repayAsset,
            _redeemQuantityUnits,
            _tradeAdapterName,
            _tradeData
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
        _executeDeleverToZeroFollower(
                _jasperVault,
                _collateralAsset,
                _repayAsset,
                _redeemQuantityUnits,
                _tradeAdapterName,
                _tradeData
        );
         callData = abi.encodeWithSelector(
            ISignalSuscriptionModule.exectueFollowStart.selector,
            address(_jasperVault)
        );
        _invokeManager(_manager(_jasperVault), address(signalSuscriptionModule), callData);
    }

    function _executeDeleverToZeroFollower(
        IJasperVault _jasperVault,
        IERC20 _collateralAsset,
        IERC20 _repayAsset,
        uint256 _redeemQuantityUnits,
        string memory _tradeAdapterName,
        bytes memory _tradeData
    ) internal {
           address[] memory followers = signalSuscriptionModule.get_followers(address(_jasperVault));           
            for (uint256 i = 0; i < followers.length; i++) {
                bytes memory callData = abi.encodeWithSelector(        
                  ILeverageModule.deleverToZeroBorrowBalance.selector,
                 IJasperVault(followers[i]),
                 _collateralAsset,
                 _repayAsset,
                 _redeemQuantityUnits,
                 _tradeAdapterName,
                 _tradeData
                );
                _execute(
                    _manager(IJasperVault(followers[i])),
                    address(leverageModule),
                    callData
                );
            }
     }

    function addCollateralAssets(
        IJasperVault _jasperVault,
        IERC20[] memory _newCollateralAssets
    ) external onlyOperator(_jasperVault) {
        bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.addCollateralAssets.selector,
            _jasperVault,
            _newCollateralAssets
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
    }

    function removeCollateralAssets(
        IJasperVault _jasperVault,
        IERC20[] memory _collateralAssets
    ) external onlyOperator(_jasperVault) {
        bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.removeCollateralAssets.selector,
            _jasperVault,
            _collateralAssets
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
    }

    function addBorrowAssets(
        IJasperVault _jasperVault,
        IERC20[] memory _newBorrowAssets
    ) external onlyOperator(_jasperVault) {
        bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.addBorrowAssets.selector,
            _jasperVault,
            _newBorrowAssets
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
    }

    function removeBorrowAssets(
        IJasperVault _jasperVault,
        IERC20[] memory _borrowAssets
    ) external onlyOperator(_jasperVault) {
        bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.removeBorrowAssets.selector,
            _jasperVault,
            _borrowAssets
        );
        _invokeManager(
            _manager(_jasperVault),
            address(leverageModule),
            callData
        );
    }

    /* ============ Internal Functions ============ */
    function _execute(
        IDelegatedManager manager,
        address module,
        bytes memory callData
    ) internal {
        try manager.interactManager(module, callData) {} catch Error(
            string memory reason
        ) {
            emit InvokeFail(address(manager), module, reason, callData);
        }
    }

    /**
     * Internal function to initialize LeverageModule on the JasperVault associated with the DelegatedManager.
     *
     * @param _jasperVault             Instance of the JasperVault corresponding to the DelegatedManager
     * @param _delegatedManager     Instance of the DelegatedManager to initialize the LeverageModule for
     */
    function _initializeModule(
        IJasperVault _jasperVault,
        IDelegatedManager _delegatedManager,
        IERC20[] memory _collateralAssets,
        IERC20[] memory _borrowAssets
    ) internal {
        bytes memory callData = abi.encodeWithSelector(
            ILeverageModule.initialize.selector,
            _jasperVault,
            _collateralAssets,
            _borrowAssets
        );
        _invokeManager(_delegatedManager, address(leverageModule), callData);
    }
}
