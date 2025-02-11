// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IVault} from "../interfaces/internal/IVault.sol";
import {IPlatformFacet} from "../interfaces/internal/IPlatformFacet.sol";
import {IVaultFacet} from "../interfaces/internal/IVaultFacet.sol";
import {IERC20} from "../interfaces/external/IERC20.sol";

contract ModuleBase {
    address public diamond;

    modifier onlyModule(){
        require(IPlatformFacet(diamond).getModuleStatus(msg.sender),"ModuleBasae:caller must be module");
        _;
    }
    modifier onlyVault(address _vault) {
        require(
            msg.sender == address(_vault),
            "ModuleBasae:caller must be vault"
        );
        require(
            IPlatformFacet(diamond).getIsVault(_vault),
            "ModuleBase:vault must in platform"
        );

        _;
    }
    modifier onlySameOwnerVault(address _vault) {
        require(
            IPlatformFacet(diamond).getIsVault(_vault),
            "ModuleBase:vault must in platform"
        );
        require(
            IPlatformFacet(diamond).getIsVault(msg.sender),
            "ModuleBase:sender must in platform"
        );
        require(!IVaultFacet(diamond).getVaultLock(_vault)&&!IVaultFacet(diamond).getVaultLock(msg.sender),"ModuleBase:vault is locked");
        require( IVault(_vault).owner()==IVault(msg.sender).owner(),   "ModuleBase:vault belong error" );
        _;
    }


    modifier onlyVaultOrManager(address _vault) {
        require(
            IPlatformFacet(diamond).getIsVault(_vault),
            "ModuleBase:vault must in platform"
        );
        require(
            msg.sender == _vault || msg.sender == IVault(_vault).owner(),
            "ModuleBase:caller error"
        );
        _;
    }
    
    modifier onlyVaultManager(address _vault) {
        require(
            msg.sender == IVault(_vault).owner(),
            "ModuleBase:caller must be vault manager"
        );
        require(
            IPlatformFacet(diamond).getIsVault(_vault),
            "ModuleBase:vault must in platform"
        );
        _;
    }
    function updatePosition(
        address _vault,
        address _component,
        uint16 _debtType
    ) internal {
        updatePositionInternal(_vault, _component, 0, _debtType);
    }

    function updatePosition(
        address _vault,
        address _component,
        uint256 _positionType,
        uint16 _debtType
    ) internal {
        updatePositionInternal(_vault, _component, _positionType, _debtType);
    }

    function updatePositionInternal(
        address _vault,
        address _component,
        uint256 _positionType,
        uint16 _debtType
    ) internal {
        uint256 balance;
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        if (_component == platformFacet.getEth()) {
            balance = _vault.balance;
            if (_positionType == 0) {
                _positionType = 1;
            }
        } else {
            balance = IERC20(_component).balanceOf(_vault);
            if (_positionType == 0) {
                _positionType = platformFacet.getTokenType(_component);
            }
        }
        require(_positionType != 0, "ModuleBase:positionType error");
        uint16 option = balance > 0 ? 1 : 0;
        uint16[3] memory sendAssetAppend = [
            uint16(_positionType),
            _debtType,
            option
        ];
        IVaultFacet(diamond).setVaultPosition(
            _vault,
            _component,
            sendAssetAppend
        );
    }
}
