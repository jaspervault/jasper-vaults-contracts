// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../eip/4337/interfaces/IEntryPoint.sol";
import "./TestVault.sol";
import {IOwnable} from "../interfaces/internal/IOwnable.sol";
import {IPlatformFacet} from "../interfaces/internal/IPlatformFacet.sol";
import {IVaultFacet} from "../interfaces/internal/IVaultFacet.sol";

/**
 * A sample factory contract for Vault
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract TestVaultFactory is Initializable, UUPSUpgradeable {
    IEntryPoint public entryPoint;
    address public diamond;
    address public vaultImp;
    address public moduleManager;
    modifier onlyOwner() {
        require(msg.sender == IOwnable(diamond).owner(), "only owner");
        _;
    }
    event CreateVault(address _wallet, uint256 _salt, address _vault);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IEntryPoint _entryPoint,
        address _diamond
    ) public initializer {
        entryPoint = _entryPoint;
        diamond = _diamond;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.addStake{value: msg.value}(unstakeDelaySec);
    }
    function setManagerModule(address _addr) external onlyOwner {
        moduleManager=_addr;
    }

    function setVaultImplementation() public onlyOwner {
        Vault accountImplementation = new Vault(entryPoint);
        IPlatformFacet(diamond).setVaultImplementation(
            address(accountImplementation)
        );
    }

    function setVaultImp() public onlyOwner{
        Vault accountImplementation = new Vault(entryPoint);
        vaultImp=address(accountImplementation);
    }

    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(
        address wallet,
        uint256 salt
    ) public returns (Vault ret) {
        address addr = getAddress(wallet, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return Vault(payable(addr));
        }
        IPlatformFacet platformFact = IPlatformFacet(diamond);
        // address accountImplementation = platformFact.getVaultImplementation();
        address  accountImplementation=vaultImp;
        ret = Vault(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    accountImplementation,
                    abi.encodeCall(Vault.initialize, (wallet, moduleManager))
                )
            )
        );
        //add to PlatformFacet
        platformFact.addWalletToVault(wallet, address(ret), salt);
        //
        IVaultFacet(diamond).setSourceType(address(ret), 1);
        // salt ==0   vault == mainVault
        if (salt == 0) {
            IVaultFacet(diamond).setVaultType(address(ret), 1);
        }
        emit CreateVault(wallet, salt, address(ret));
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(
        address wallet,
        uint256 salt
    ) public view returns (address) {
        // address accountImplementation = IPlatformFacet(diamond)
        //     .getVaultImplementation();
        address accountImplementation=vaultImp;
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            accountImplementation,
                            abi.encodeCall(Vault.initialize, (wallet, moduleManager))
                        )
                    )
                )
            );
    }

    function getWalletToVault(
        address wallet
    ) public view returns (address[] memory) {
        return IPlatformFacet(diamond).getAllVaultByWallet(wallet);
    }

    function getVaultListByPage(
        address wallet,
        uint256 page,
        uint256 pageSize
    ) public view returns (address[] memory) {
        return
            IPlatformFacet(diamond).getVaultListByPage(wallet, page, pageSize);
    }

    function getVaultToSalt(address vault) external view returns (uint256) {
        return IPlatformFacet(diamond).getVaultToSalt(vault);
    }

    function getAllVaultLength(address wallet) external view returns (uint256) {
        return IPlatformFacet(diamond).getAllVaultLength(wallet);
    }

    function getVaultMaxSalt(address wallet) external view returns (uint256) {
        uint salt = 0;
        address[] memory vaultList = IPlatformFacet(diamond)
            .getAllVaultByWallet(wallet);
        for (uint i; i < vaultList.length; i++) {
            uint nowSalt = this.getVaultToSalt(vaultList[i]);
            if (nowSalt >= salt) {
                salt = nowSalt;
            }
        }
        return salt;
    }
    function getVaultMaxSaltAddress(address wallet) external view returns (address,uint256) {
        uint salt = 0;
        address[] memory vaultList = IPlatformFacet(diamond)
            .getAllVaultByWallet(wallet);
        for (uint i; i < vaultList.length; i++) {
            uint nowSalt = this.getVaultToSalt(vaultList[i]);
            if (nowSalt >= salt) {
                salt = nowSalt;
            }
        }
        if(salt<=1){
            salt=2;
        }else{
            salt=salt+1;
        }
        return (getAddress( wallet, salt+1), salt+1);
    }
}