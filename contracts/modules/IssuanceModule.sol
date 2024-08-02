// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../lib/ModuleBase.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20 as OrignIERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Invoke} from "../lib/Invoke.sol";
import {IIssuanceModule} from "../interfaces/internal/IIssuanceModule.sol";
import {IIssuanceFacet} from "../interfaces/internal/IIssuanceFacet.sol";

contract IssuanceModule is
    ModuleBase,
    IIssuanceModule,
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Invoke for IVault;
    using SafeERC20 for IERC20;
    using SafeERC20 for OrignIERC20;
    modifier onlyOwner() {
        require(
            msg.sender == IOwnable(diamond).owner(),
            "IssuanceModule:only owner"
        );
        _;
    }

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

    function setProxyIssueWhiteList(
        address _vault,
        address _issuer,
        bool _status
    ) external onlyVaultOrManager(_vault) {
        require(_issuer != address(0), "IssuanceModule:issuer error");
        IIssuanceFacet issuanceFacet = IIssuanceFacet(diamond);
        require(IIssuanceFacet.IssueMode.Default ==issuanceFacet.getIssueMode(_vault),"IssuanceModule:IssueMode error");
        issuanceFacet.setProxyIssueWhiteList(_vault, _issuer, _status);
    }

    function getWhiteListAndMode(
        address _vault,
        address _issuer
    ) external view returns (IIssuanceFacet.IssueMode, bool) {
        IIssuanceFacet issuanceFacet = IIssuanceFacet(diamond);
        bool status = issuanceFacet.getProxyIssueWhiteList(_vault, _issuer);
        IIssuanceFacet.IssueMode mode = issuanceFacet.getIssueMode(_vault);
        return (mode, status);
    }

    /**
	If _from is of platform vault, check whether it is locked. If it is not locked, check whether _from is locked
	If _from is not platform vault
	     _from needs to approve the vault amount. If it is eth, please directly transfer the money to the vault for record
	If _from and vault belong to the same wallet, it is vault transfer
	 */
    function issue(
        address _vault,
        address payable _from,
        address[] memory _assets,
        uint256[] memory _amounts
    ) external payable nonReentrant onlyVaultOrManager(_vault) {
        
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        IIssuanceFacet issuanceFacet = IIssuanceFacet(diamond);
        require(
            issuanceFacet.getIssueMode(_vault) !=
                IIssuanceFacet.IssueMode.Proxy,
            "IssuanceModule:issue mode error"
        );

        require(
            !vaultFacet.getVaultLock(_vault),
            "IssuanceModule:vault is locked"
        );
        bool isCheck;
        bool isVault = platformFacet.getIsVault(_from);
        if (isVault) {
            require(
                !vaultFacet.getVaultLock(_from),
                "IssuanceModule:vault is locked"
            );
            if (IVault(_vault).owner() == IVault(_from).owner()) {
                isCheck = true;
            }
        }

        for (uint256 i; i < _assets.length; i++) {
            //check asset
            validAsset(_vault, _assets[i]);
            //transferForm
            if (_assets[i] == platformFacet.getEth()) {
                if (isCheck) {
                    IVault(_from).invokeTransferEth(_vault, _amounts[i]);
                } else {
                    (bool success, ) = _vault.call{value: msg.value}("");
                    require(success, "IssuanceModule:tranfer error");
                }
            } else {
                if (isCheck) {
                    IVault(_from).invokeApprove(
                        _assets[i],
                        _vault,
                        _amounts[i]
                    );
                }
                IVault(_vault).invokeTransferFrom(
                    _assets[i],
                    _from,
                    _vault,
                    _amounts[i]
                );
            }
            //update Postion
            updatePosition(_vault, _assets[i], 0);
            if (isVault) {
                updatePosition(_from, _assets[i], 0);
            }
        }
        issuanceFacet.setIssueMode(_vault, IIssuanceFacet.IssueMode.Normal);

        emit Issue(_vault, _from, _assets, _amounts);
    }

    //approve module  then execute function
    function issueAndProxy(
        address _vault,
        address[] memory _assets,
        uint256[] memory _amounts
    ) external payable nonReentrant {
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        IIssuanceFacet issuanceFacet = IIssuanceFacet(diamond);
        address _from = msg.sender;
        require(
            issuanceFacet.getProxyIssueWhiteList(_vault, _from),
            "IssuanceModule:from error"
        );
        IIssuanceFacet.IssueMode mode = issuanceFacet.getIssueMode(_vault);
        if (mode == IIssuanceFacet.IssueMode.Default) {
            issuanceFacet.setIssueMode(_vault, IIssuanceFacet.IssueMode.Proxy);
            issuanceFacet.setIssuer(_vault, _from);
        } else {
            require(
                _from != address(0) && issuanceFacet.getIssuer(_vault) == _from,
                "IssuanceModule:issue mode error"
            );
        }
        for (uint256 i; i < _assets.length; i++) {
            validAsset(_vault, _assets[i]);
            if (_assets[i] == platformFacet.getEth()) {
                (bool success, ) = _vault.call{value: msg.value}("");
                require(success, "IssuanceModule:tranfer error");
            } else {
                OrignIERC20(_assets[i]).safeTransferFrom(_from, _vault, _amounts[i]);
            }
            updatePosition(_vault, _assets[i], 0);
        }
        emit Issue(_vault, _from, _assets, _amounts);
    }

    /**
	  _assetsType ==1   asset  is token
	  _assetsType ==2   asset  is nft
	 */
    function redeem(
        address _vault,
        uint256[] memory _assetsType,
        address[] memory _assets,
        uint256[] memory _amounts
    ) external nonReentrant onlyVaultOrManager(_vault) {
        address payable _to = payable(IVault(_vault).owner());
        IIssuanceFacet issuanceFacet = IIssuanceFacet(diamond);
        IIssuanceFacet.IssueMode mode = issuanceFacet.getIssueMode(_vault);
        if (mode == IIssuanceFacet.IssueMode.Proxy) {
            _to = payable(issuanceFacet.getIssuer(_vault));
        }
        executeRedeem(_vault, _to, _assetsType, _assets, _amounts);
        deleteVaultProxyMode(_vault);
    }

    /**
	   proxy  redeem  asset
	 */
    function redeemProxy(
        address _vault,
        uint256[] memory _assetsType,
        address[] memory _assets,
        uint256[] memory _amounts
    ) external nonReentrant {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        require(
            !vaultFacet.getVaultLock(_vault),
            "IssuanceModule:vault is locked"
        );
        IIssuanceFacet issuanceFacet = IIssuanceFacet(diamond);
        IIssuanceFacet.IssueMode mode = issuanceFacet.getIssueMode(_vault);
        address _to = issuanceFacet.getIssuer(_vault);
        require(
            mode == IIssuanceFacet.IssueMode.Proxy && _to == msg.sender,
            "IssuanceModule:redeemProxy error"
        );
        executeRedeem(_vault, payable(_to), _assetsType, _assets, _amounts);
        deleteVaultProxyMode(_vault);
    }

    function executeRedeem(
        address _vault,
        address payable _to,
        uint256[] memory _assetsType,
        address[] memory _assets,
        uint256[] memory _amounts
    ) internal {
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        uint256 amount;
        for (uint256 i; i < _assets.length; i++) {
            amount = _amounts[i];
            //check asset
            validAsset(_vault, _assets[i]);
            //transfer to metamask
            if (_assets[i] != platformFacet.getEth()) {
                if (_assetsType[i] == 1) {
                    if (amount == 0) {
                        amount = IERC20(_assets[i]).balanceOf(_vault);
                    }
                    IVault(_vault).invokeTransfer(_assets[i], _to, amount);
                } else if (_assetsType[i] == 2) {
                    IVault(_vault).invokeTransferNft( _assets[i], _to, _amounts[i] );              
                } else {
                    revert("IssuanceModule:assetsType error");
                }
            } else {
                if (amount == 0) {
                    amount = _vault.balance;
                }
                IVault(_vault).invokeTransferEth(_to, amount);
            }
            //update Postion
            updatePosition(_vault, _assets[i], 0);
            if (platformFacet.getIsVault(_to)) {
                updatePosition(_to, _assets[i], 0);
            }
        }
        emit Redeem(_vault,_to,_assetsType, _assets, _amounts);
    }

    function deleteVaultProxyMode(address _vault) internal {
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        uint256 count = platformFacet.getAssetTypeCount() + 1;
        uint16[] memory _positionTypes = new uint16[](count);
        for (uint16 i; i < count; i++) {
            _positionTypes[i] = i;
        }
        uint256 total = IVaultFacet(diamond)
            .getVaultAllPosition(_vault, _positionTypes)
            .length;
        if (total == 0) {
            IIssuanceFacet issuanceFacet = IIssuanceFacet(diamond);
            issuanceFacet.setIssuer(_vault, address(0));
            issuanceFacet.setIssueMode(
                _vault,
                IIssuanceFacet.IssueMode.Default
            );
        }
    }

    function validAsset(address _vault, address _asset) internal view {
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        //check asset in platform
        uint256 assetType = platformFacet.getTokenType(_asset);
        require(
            assetType != 0,
            "IssuanceModule:asset must be platform allowed"
        );
        //check asset in vault
        assetType = vaultFacet.getVaultTokenType(_vault, _asset);
        require(assetType != 0, "IssuanceModule:asset must be vault allowed");
    }
}
