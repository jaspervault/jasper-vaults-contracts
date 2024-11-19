// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { IOwnable } from "../interfaces/internal/IOwnable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 as OrignIERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Invoke } from "../lib/Invoke.sol";
import "../lib/ModuleBase.sol";

import { IIssuanceFacet } from "../interfaces/internal/IIssuanceFacet.sol";
import { IPoolModule } from "../interfaces/internal/IPoolModule.sol";

// import "hardhat/console.sol";

contract PoolBase is
    ModuleBase,
    IPoolModule,
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
 {
    using Invoke for IVault;
    using SafeERC20 for OrignIERC20;

    address   public vault;
    address   public asset;
    enum PermissionType{
        Permissioned,
        PermissionLess
    }

    PermissionType  public permissionType;
    mapping(address => bool) addressPermissionMap;

    modifier onlyOwner() {
        require(
            msg.sender == IOwnable(diamond).owner(),
            "PoolBase:only owner"
        );
        _;
    }

    modifier onlyPermissioned() {

        if(permissionType == PermissionType.Permissioned){
            require(
                addressPermissionMap[msg.sender],
                "PoolBase:only permissioned"
            );
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vault,address _diamond,address _asset) virtual public initializer {
        __UUPSUpgradeable_init();
        diamond = _diamond;
        vault = _vault;
        asset = _asset;
        permissionType = PermissionType.PermissionLess;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // 0 Permissioned
    // 1 PermissionLess
    function setPermissionType(PermissionType _permissionType) public onlyOwner(){
        permissionType = _permissionType;
    }

    /**
     * depoist to investor 
     * @param _investor investor for 
     */
    function addInvestor(address _investor) public onlyOwner(){

        require(permissionType == PermissionType.Permissioned,"only permissioned need to add invest by admin");
        require(addressPermissionMap[_investor] ,"already set permission , no need to add again");

        addressPermissionMap[_investor] = true;

    }

    /**
     * depoist to vault 
     * @param _amount deposit asset amount include:ETH,USDT,WETH
     */
    function depositToVault(
        uint256 _amount
    ) internal{

        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        IIssuanceFacet issuanceFacet = IIssuanceFacet(diamond);
        address _from = msg.sender;

        issuanceFacet.setIssueMode(vault, IIssuanceFacet.IssueMode.Proxy);
        issuanceFacet.setIssuer(vault, address(this));
        // issuanceFacet.setIsHosting(vault, address(this));
        // issuanceFacet.setproductTypes(vault, address(this));
        
        validAsset(vault, asset);

        if (asset == platformFacet.getEth()) {
            (bool success, ) = vault.call{value: msg.value}("");
            require(success, "PoolBase:tranfer error");
        } else {
            OrignIERC20(asset).safeTransferFrom(_from, vault, _amount);
        }
        updatePosition(vault, asset, 0);
        emit Issue(vault, _from, asset, _amount);

    }

    /**
     * withdraw from vault
     * @param _amount withdraw asset amount include:ETH,USDT,WETH
     */
    function withdrawFromVault(
        address _profitAsset,
        address _to,
        uint256 _amount
    ) internal{
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        require(
            !vaultFacet.getVaultLock(vault),
            "PoolBase:vault is locked"
        );

        IIssuanceFacet issuanceFacet = IIssuanceFacet(diamond);
        IIssuanceFacet.IssueMode mode = issuanceFacet.getIssueMode(vault);
        // address _to = issuanceFacet.getIssuer(vault);
        require(
            mode == IIssuanceFacet.IssueMode.Proxy,
            "PoolBase:redeemProxy error"
        );

        executeRedeem(_profitAsset, payable(_to), _amount);
    }

    function validAsset(address _vault, address _asset) internal view {
        
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
        //check asset in platform
        uint256 assetType = platformFacet.getTokenType(_asset);
        require(
            assetType != 0,
            "PoolBase:asset must be platform allowed"
        );
        //check asset in vault
        assetType = vaultFacet.getVaultTokenType(_vault, _asset);
        require(assetType != 0, "PoolBase:asset must be vault allowed");
    }

    function executeRedeem(
        address _profitAsset,
        address payable _to,
        uint256 _amount
    ) internal {
        IPlatformFacet platformFacet = IPlatformFacet(diamond);
       
        //check asset
        validAsset(vault, _profitAsset);
        //transfer to metamask
        if (_profitAsset != platformFacet.getEth()) {
            IVault(vault).invokeTransfer(_profitAsset, _to, _amount);
        } else {
            IVault(vault).invokeTransferEth(_to, _amount);
        }
        //update Postion
        updatePosition(vault, _profitAsset, 0);

    }


}
