// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "./utils/Create2.sol";
import "./proxy/ERC1967/ERC1967Proxy.sol";
import "./Vault.sol";
import "./interfaces/IDelegatedManagerFactory.sol";
import "./interfaces/IJasperVault.sol";
import "./interfaces/IDelegatedManager.sol";
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
    mapping(address=>address[]) public  acccount2Vault;
    mapping(address=>uint256)  public  vault2Index;
    event DeleteVaultRecord(address _account,address _vault);
    event SetSetting(IEntryPoint _entryPoint,IDelegatedManagerFactory _delegatedManagerFactory);
    IEntryPoint public entryPoint;
    struct AccountInfo{
        address vault;
        address jasperVault;
        uint256 jasperVaultType;
        uint256 vaultIndex;
        address manager;
        bool  isInitial;
    }
    mapping(address=>uint256)  public account2Num;
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
        emit SetSetting(_entryPoint,_delegatedManagerFactory);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.addStake{value : msg.value}(unstakeDelaySec);
    }

    function  deleteVaultRecord(address _account,address[] memory _delList) external onlyOwner{   
            for(uint256 i=0;i<_delList.length;i++){
                  address[] memory vaultList=acccount2Vault[_account];
                  (bool isExist,uint256 index)=contains(vaultList,_delList[i]);
                  if(isExist){
                        acccount2Vault[_account][index]=acccount2Vault[_account][vaultList.length-1];
                        acccount2Vault[_account].pop();
                        emit DeleteVaultRecord(_account,_delList[i]);
                  }
            }
    }

    function contains(address[] memory _list,address _a) internal pure returns(bool,uint256){
         bool isExist;
         uint256 index;
         for(uint256 i=0;i<_list.length;i++){
                 if(_a==_list[i]){
                     isExist=true;
                     index=i;
                 }
         }
         return (isExist,index);
    }

    function getAccountByIndex(address _account,uint256 salt) external view returns (AccountInfo memory){
            AccountInfo memory info;
            info.vault=getAddress(_account,salt);
            info.jasperVault=delegatedManagerFactory.account2setToken(info.vault);
            info.jasperVaultType=delegatedManagerFactory.jasperVaultType(info.jasperVault);
            info.vaultIndex=vault2Index[info.vault];
            info.isInitial=delegatedManagerFactory.jasperVaultInitial(info.jasperVault);
            if(info.jasperVault !=address(0x00)){
               info.manager=IJasperVault(info.jasperVault).manager();
            }
            return info;
    }

    function getAccountByVault(address _account,address _vault) external view returns(AccountInfo memory){
            AccountInfo memory info;
            uint256 salt=vault2Index[_vault];
            info.vault=getAddress(_account,salt);
            info.jasperVault=delegatedManagerFactory.account2setToken(info.vault);
            info.jasperVaultType=delegatedManagerFactory.jasperVaultType(info.jasperVault);
            info.vaultIndex=salt;
            info.isInitial=delegatedManagerFactory.jasperVaultInitial(info.jasperVault);
            if(info.jasperVault !=address(0x00)){
               info.manager=IJasperVault(info.jasperVault).manager();
            }
            return info;  
    }

    function getAccountByManager(address ,address _manager) external view returns(AccountInfo memory){
            AccountInfo memory info;           
            info.vault=IDelegatedManager(_manager).owner();
            info.jasperVault=delegatedManagerFactory.account2setToken(info.vault);
            info.jasperVaultType=delegatedManagerFactory.jasperVaultType(info.jasperVault);
            info.vaultIndex=vault2Index[info.vault];
            info.isInitial=delegatedManagerFactory.jasperVaultInitial(info.jasperVault);
            info.manager=_manager;
            return info;        
    }

    function getAccountList(address _account,uint256 _page,uint256 _pageSize) external view returns(AccountInfo[] memory){
        require(_page> 0 && _pageSize>0, "_page and _pageSize  must greater than zero");     
        address[] memory vaultList=acccount2Vault[_account];
        uint256 start=(_page-1)*_pageSize;
        uint256 end=_page*_pageSize;
        if(start>=vaultList.length){
             AccountInfo[] memory zeroList=new AccountInfo[](0);
             return zeroList;
        }
        if(end>=vaultList.length){
             end=vaultList.length;
        }
        uint256 len=end-start;
        AccountInfo[] memory infos=new AccountInfo[](len);
        for(uint256 i=0;i<len;i++) {
              AccountInfo memory info;
              info.vault=vaultList[start+i];
              info.jasperVault=delegatedManagerFactory.account2setToken(info.vault);
              info.jasperVaultType=delegatedManagerFactory.jasperVaultType(info.jasperVault);
              info.vaultIndex=vault2Index[info.vault];
              info.isInitial=delegatedManagerFactory.jasperVaultInitial(info.jasperVault);
              if(info.jasperVault !=address(0x00)){
                  info.manager=IJasperVault(info.jasperVault).manager();
              }
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
        address[] memory vaultList=acccount2Vault[managerAddr];     
       (bool isExist,uint256 index)= contains(vaultList,address(ret));
        if(!isExist){
            acccount2Vault[managerAddr].push(address(ret));
            vault2Index[address(ret)]=salt;
            account2Num[managerAddr]=account2Num[managerAddr]+1;
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
