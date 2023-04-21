// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "./utils/Create2.sol";
import "./proxy/ERC1967/ERC1967Proxy.sol";
import "./Vault.sol";

import "./interfaces/IDelegatedManagerFactory.sol";


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";





/**
 * A sample factory contract for SimpleAccount
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract VaultFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {


    Vault public  accountImplementation;

    IDelegatedManagerFactory  public delegatedManagerFactory;

    mapping(address=>uint256)  public  account2Num;
    //user account address->index
    mapping(address=>uint256[]) public account2salts;

    mapping(address=>mapping(address=>uint256)) public  account2Index;

    //user account -> jasperVault
    IEntryPoint public entryPoint;


    struct AccountInfo{
        address vault;
        address jasperVault;
        uint256 jasperVaultType;
        uint256 vaultIndex;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
      _disableInitializers();
    }

    function initialize(IEntryPoint _entryPoint,IDelegatedManagerFactory _delegatedManagerFactory) initializer public {
        accountImplementation = new Vault(_entryPoint);
        entryPoint=_entryPoint;
        delegatedManagerFactory=_delegatedManagerFactory;
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function setSetting(IEntryPoint _entryPoint,IDelegatedManagerFactory _delegatedManagerFactory) external onlyOwner{
        accountImplementation = new Vault(_entryPoint);
        entryPoint=_entryPoint;
        delegatedManagerFactory=_delegatedManagerFactory;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.addStake{value : msg.value}(unstakeDelaySec);
    }

    function getAccountList(address _account,uint256 _page,uint256 _pageSize) external view returns(AccountInfo[] memory){
        require(_page> 0 && _pageSize>0, "_page and _pageSize  must greater than zero");
        uint256 start=(_page-1)*_pageSize;
        uint256 total=account2Num[_account];
        if(start>total){
           AccountInfo[] memory zeroList=new AccountInfo[](0);
           return zeroList;
        }
        uint256 end=(_page)*_pageSize-1;
        uint256 len;
        if(end>total){
           len=total-start;
        }else{
           len=_pageSize;
        }
        AccountInfo[] memory infos=new AccountInfo[](len);
        AccountInfo memory info;
        uint256 index;
        for(uint256 i=0;i<len;i++) {
              index=i+start;
              uint256 salt=account2salts[_account][index];
              info.vault=getAddress(_account,salt);
              info.jasperVault=delegatedManagerFactory.acccount2setToken(info.vault);
              info.jasperVaultType=delegatedManagerFactory.jasperVaultType(info.vault);
              info.vaultIndex=account2Index[_account][info.vault];
              infos[i]=info;
        }
        return  infos;
    }
    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(address managerAddr,uint256 salt) public returns (Vault ret) {
        address addr = getAddress(managerAddr, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return Vault(payable(addr));
        }
        ret = Vault(payable(new ERC1967Proxy{salt : bytes32(salt)}(
                address(accountImplementation),
                abi.encodeCall(Vault.initialize, (managerAddr))
            )));
        //save user info
        uint256[] memory salts=account2salts[managerAddr];
        bool isExist;
        for(uint256 i=0;i<salts.length;i++){
              if(salt==salts[i]){
                  isExist=true;
              }
        }
        if(!isExist){
            account2salts[managerAddr].push(salt);
            account2Num[managerAddr]=salts.length+1;
            account2Index[managerAddr][addr]=salt;
        }
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(address managerAddr,uint256 salt) public view returns (address) {
        return Create2.computeAddress(bytes32(salt), keccak256(abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    address(accountImplementation),
                    abi.encodeCall(Vault.initialize, (managerAddr))
                )
            )));
    }
}
