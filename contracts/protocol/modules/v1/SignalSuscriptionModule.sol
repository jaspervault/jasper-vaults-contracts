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
import {IJasperVault} from "../../../interfaces/IJasperVault.sol";
import {ModuleBase} from "../../lib/ModuleBase.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PreciseUnitMath} from "../../../lib/PreciseUnitMath.sol";
import {AddressArrayUtils} from "../../../lib/AddressArrayUtils.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {ISubscribeFeePool} from "../../../interfaces/ISubscribeFeePool.sol";

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

    using Invoke for IJasperVault;

    using PreciseUnitMath for uint256;
    using AddressArrayUtils for address[];

    mapping(address => address[]) public followers;

    mapping(address => bool) public isExectueFollow;
   
    uint256 public warningLine;
    uint256 public unsubscribeLine;
    //1%=1e16  100%=1e18
    uint256 public platformFee;
    address public platform_vault;

    mapping(address => address) public Signal_provider;
    mapping(IJasperVault => uint256) public jasperVaultPreBalance;

    mapping(address=>uint256)  public followFees;

    mapping(address=>uint256) public profitShareFees;



    ISubscribeFeePool public  subscribeFeePool;


    /* ============ Constructor ============ */

    constructor(
        IController _controller,
        ISubscribeFeePool _subscribeFeePool,
        uint256 _warningLine,
        uint256 _unsubscribeLine,
        uint256 _platformFee,
        address _platform_vault
    ) public ModuleBase(_controller) {
        warningLine = _warningLine;
        unsubscribeLine = _unsubscribeLine;
        platformFee = _platformFee;
        subscribeFeePool = _subscribeFeePool;
        platform_vault = _platform_vault;
    }

    /* ============ External Functions ============ */

    function exectueFollowStart(
        address _jasperVault
    ) external nonReentrant onlyManagerAndValidSet(IJasperVault(_jasperVault)) {
        require(
            !isExectueFollow[_jasperVault],
            "exectueFollow  status not false"
        );
        isExectueFollow[_jasperVault] = true;
    }

    function exectueFollowEnd(
        address _jasperVault
    ) external nonReentrant onlyManagerAndValidSet(IJasperVault(_jasperVault)) {
        require(isExectueFollow[_jasperVault], "exectueFollow status not true");
        isExectueFollow[_jasperVault] = false;
    }

    //1%=1e16  100%=1e18
    function setPlatformAndPlatformFee(
        ISubscribeFeePool _subscribeFeePool,
        address _platform_vault,
        uint256 _warningLine,
        uint256 _unsubscribeLine,
        uint256 _fee
    ) external nonReentrant onlyOwner {
        subscribeFeePool = _subscribeFeePool;
        platformFee = _fee;
        platform_vault = _platform_vault;
        warningLine = _warningLine;
        unsubscribeLine = _unsubscribeLine;
    }

    /**
     * Initializes this module to the JasperVault. Only callable by the JasperVault's manager.
     *
     * @param _jasperVault                 Instance of the JasperVault to initialize
     */
    function initialize(
        IJasperVault _jasperVault
    )
        external
        onlyValidAndPendingSet(_jasperVault)
        onlySetManager(_jasperVault, msg.sender)
    {
        _jasperVault.initializeModule();
    }

    /**
     * Removes this module from the JasperVault, via call by the JasperVault. Left with empty logic
     * here because there are no check needed to verify removal.
     */
    function removeModule() external override {}

    function subscribe(
        IJasperVault _jasperVault,
        address target
    ) external nonReentrant onlyManagerAndValidSet(_jasperVault) {
        uint256 preBalance = controller
            .getSetValuer()
            .calculateSetTokenValuation(
                _jasperVault,
                _jasperVault.masterToken()
            );

        uint256 decimals=IERC20(_jasperVault.masterToken()).decimals();  
        jasperVaultPreBalance[_jasperVault] =preBalance.mul(10**decimals).preciseMul(_jasperVault.totalSupply()).div(PreciseUnitMath.preciseUnit());
        followers[target].push(address(_jasperVault));
        Signal_provider[address(_jasperVault)] = target;
        followFees[address(_jasperVault)]=IJasperVault(target).followFee();
        profitShareFees[address(_jasperVault)]=IJasperVault(target).profitShareFee();
    }



    function unsubscribe(
        IJasperVault _jasperVault,
        address target
    ) external nonReentrant onlyManagerAndValidSet(_jasperVault) {
        followers[target].removeStorage(address(_jasperVault));
      
    }

    function removeFollower(
        address target,
        address follower
    ) external nonReentrant onlyOwner {
        followers[target].removeStorage(follower);
        delete Signal_provider[follower];
    }

    function get_followers(
        address target
    ) external view returns (address[] memory) {
          return followers[target]; 
    }

    function get_signal_provider(
        IJasperVault _jasperVault
    ) external view returns (address) {
        return Signal_provider[address(_jasperVault)];
    }

    //calculate fee
    function handleFee(
        IJasperVault _jasperVault
    ) external nonReentrant onlyManagerAndValidSet(_jasperVault) {
        address masterToken = _jasperVault.masterToken();
        uint256 preBalance = jasperVaultPreBalance[_jasperVault];
        address target = Signal_provider[address(_jasperVault)];
        delete jasperVaultPreBalance[_jasperVault];
        delete Signal_provider[address(_jasperVault)];
        uint256 nextBalance=IERC20(masterToken).balanceOf(address(_jasperVault));
        uint256 totalSupply = _jasperVault.totalSupply();
        uint256 followFee=followFees[address(_jasperVault)];
        uint256 strategistFeeBalance=preBalance.preciseMul(followFee);      
        if (nextBalance > preBalance) {  
            //Calculated profit
            uint256   fee=nextBalance-preBalance;
            //calculate platformFee
            uint256 platformFeeBalance = fee.preciseMul(platformFee);
            if(platformFeeBalance>0){
                //approve
                _jasperVault.invokeApprove(
                    masterToken,
                    address(subscribeFeePool),
                    platformFeeBalance
                );
                desposit(
                    _jasperVault,
                    masterToken,
                    platform_vault,
                    platformFeeBalance
                );
            }
            //calculate strategistsFee
            uint256 _strategistFee=profitShareFees[address(_jasperVault)];
            strategistFeeBalance =strategistFeeBalance.add(fee.preciseMul(_strategistFee));  
        }
   
            //approve
            _jasperVault.invokeApprove(
                masterToken,
                address(subscribeFeePool),
                strategistFeeBalance
            );
            desposit(_jasperVault, masterToken, target, strategistFeeBalance);
     
            //update position
            uint256 tokenBalance = IERC20(masterToken).balanceOf(
                address(_jasperVault)
            );
            tokenBalance = tokenBalance.preciseDiv(totalSupply);       
            _updatePosition(_jasperVault, masterToken, tokenBalance, 0);
       
    }

    function desposit(
        IJasperVault _jasperVault,
        address _token,
        address _to,
        uint256 _amount
    ) internal {
        bytes memory callData = abi.encodeWithSignature(
            "desposit(address,address,uint256)",
            _token,
            _to,
            _amount
        );
        _jasperVault.invoke(address(subscribeFeePool), 0, callData);
    }

    function _updatePosition(
        IJasperVault _jasperVault,
        address _token,
        uint256 _newPositionUnit,
        uint256 _coinType
    ) internal {
        _jasperVault.editCoinType(_token, _coinType);
        _jasperVault.editDefaultPosition(_token, _newPositionUnit);
    }
}
