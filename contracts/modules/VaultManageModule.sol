// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../lib/ModuleBase.sol";

import {IVaultManageModule} from "../interfaces/internal/IVaultManageModule.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {IPaymasterFacet} from "../interfaces/internal/IPaymasterFacet.sol";
import {IVault} from "../interfaces/internal/IVault.sol";

contract VaultManageModule is
    ModuleBase,
    IVaultManageModule,
    Initializable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _diamond) public initializer {
        __UUPSUpgradeable_init();
        diamond = _diamond;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    modifier onlyOwner() {
        require(
            msg.sender == IOwnable(diamond).owner(),
            "VaultManageModule:only owner"
        );
        _;
    }

    function removeVault(address _vault) external onlyVault(_vault) {
        address _wallet = IOwnable(_vault).owner();
        require(_wallet != address(0), "VaultManageModule:invalid vault");
        address[] memory vaults = new address[](1);
        vaults[0] = _vault;
        IPlatformFacet(diamond).removeWalletToVault(_wallet, vaults);
        emit RemoveVault(_wallet, _vault);
    }
    function validVaultModuleV2(  
        address _module,
        uint256 _value,
        bytes memory func) external{
        validVaultModule(_module,_value,func);
        hanldeFuncQuota(func, msg.sender);
    }
    function validVaultModule(
        address _module,
        uint256 /** */,
        bytes memory func
    )  public  view{
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        require(
            func.length >= 4 || func.length == 0,
            "VaultManageModule:invalid func"
        );
        bytes4 selector;
        assembly {
            selector := mload(add(func, 32))
        }

        if (vaultFacet.getVaultLock(msg.sender)) {
            require(
                vaultFacet.getFuncWhiteList(msg.sender, selector),
                "VaultManageModule:vault is locked"
            );
        } else {
            require(
                !vaultFacet.getFuncBlackList(msg.sender, selector),
                "VaultManageModule:func in balackList"
            );
        }
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        require(
            platformFacet.getIsVault(msg.sender),
            "VaultManageModule:invalid vault"
        );
        require(
            platformFacet.getModuleStatus(_module),
            "VaultManageModule:invalid module"
        );
        if (_module != address(this)) {
            require(
                vaultFacet.getVaultModuleStatus(msg.sender, _module),
                "VaultManageModule:invalid module in vault"
            );
        }
       
    }
    function hanldeFuncQuota(bytes memory func, address _vault) internal {
        bytes4 selector;
        assembly {
            selector := mload(add(func, 32))
        }
        if (IPaymasterFacet(diamond).getFuncFeeWhitelist(selector) == IPaymasterFacet.FreeGasFuncType.Normal) {
            IPaymasterFacet(diamond).setQuotaWhiteList(
                    2 ,
                    IVault(_vault).owner(),
                    // TODO: need set fee with eth/usd 
                    1 ether
                );
            IPaymasterFacet(diamond). setQuotaLimit( IVault(_vault).owner(),1);
        }
    }
    function registToPlatform(address _vault, uint256 _salt) external {
        require(_salt != 0, "VaultManageModule:_salt error");
        IVault vault = IVault(_vault);
        address imp = vault.getImplementation();
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        address platformImp = platformFacet.getVaultImplementation();
        require(
            platformFacet.getProxyCodeHash(_vault),
            "VaultManageModule:vault mismatch condition"
        );
        require(
            imp == platformImp,
            "VaultManageModule:vault implementation must be the same as the platform"
        );
        address owner = vault.owner();
        require(
            msg.sender == owner,
            "VaultManageModule:caller must be vault owner"
        );
        platformFacet.addWalletToVault(owner, _vault, _salt);
        IVaultFacet(diamond).setSourceType(owner, 2);
        emit RegistToPlatform(_vault, _salt, 2);
    }

    function setVaultMasterToken(
        address _vault,
        address _masterToken
    ) external onlyVault(_vault) {
        require(
            IPlatformFacet(diamond).getTokenType(_masterToken) != 0,
            "VaultManageModule:invalid materToken"
        );
        IVaultFacet(diamond).setVaultMasterToken(_vault, _masterToken);
    }

    function setVaultProtocol(
        address _vault,
        address[] memory _protocols,
        bool[] memory _status
    ) external onlyVault(_vault) {
        IVaultFacet(diamond).setVaultProtocol(_vault, _protocols, _status);
    }

    function setVaultTokens(
        address _vault,
        address[] memory _tokens,
        uint256[] memory _types
    ) external onlyVault(_vault) {
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        for (uint256 i; i < _tokens.length; i++) {
            require(
                platformFacet.getTokenType(_tokens[i]) != 0,
                "VaultManageModule:invalid token"
            );
        }
        IVaultFacet(diamond).setVaultTokens(_vault, _tokens, _types);
    }

    function setVaultModule(
        address _vault,
        address[] memory _modules,
        bool[] memory _status
    ) external onlyVault(_vault) {
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        for (uint256 i; i < _modules.length; i++) {
            require(
                platformFacet.getModuleStatus(_modules[i]),
                "VaultManageModule:invalid module"
            );
        }
        IVaultFacet(diamond).setVaultModules(_vault, _modules, _status);
    }

    function setVaultType(
        address _vault,
        uint256 _vaultType
    ) external onlyVault(_vault) {
        uint vaultIndex = IPlatformFacet(diamond).getVaultToSalt(_vault);
        require(
             vaultIndex != 0 ,
            "VaultManageModule:Main Vault 0 not allow edit"
        );
        if (vaultIndex == 1){
          require( _vaultType == 1,"VaultManageModule: _vault 1 only set type 1");
        }
        IVaultFacet(diamond).setVaultType(_vault, _vaultType);
    }
}
