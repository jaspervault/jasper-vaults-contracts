// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "./Create2.sol";
import "../../proxy/ERC1967/ERC1967Proxy.sol";

import "./Vault.sol";

/**
 * A sample factory contract for SimpleAccount
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract VaultFactory {
    Vault public immutable accountImplementation;
    mapping(address=>uint256)  public  account2Num;
    //user account address->index
    mapping(address=>uint256[]) public account2salts;

    IEntryPoint public entryPoint;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender==owner,"caller is not the owner");
        _;
    }


    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new Vault(_entryPoint);
        owner=msg.sender;
        entryPoint=_entryPoint;
    }

    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.addStake{value : msg.value}(unstakeDelaySec);
    }
    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(address owner,uint256 salt) public returns (Vault ret) {
        address addr = getAddress(owner, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return Vault(payable(addr));
        }
        ret = Vault(payable(new ERC1967Proxy{salt : bytes32(salt)}(
                address(accountImplementation),
                abi.encodeCall(Vault.initialize, (owner))
            )));
        //save user info    
        uint256[] memory salts=account2salts[owner];
        bool isExist;
        for(uint256 i=0;i<salts.length;i++){
              if(salt==salts[i]){
                  isExist=true;
              }
        }
        if(!isExist){
            account2salts[owner].push(salt);
            account2Num[owner]=salts.length+1;
        }
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(address owner,uint256 salt) public view returns (address) {
        return Create2.computeAddress(bytes32(salt), keccak256(abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    address(accountImplementation),
                    abi.encodeCall(Vault.initialize, (owner))
                )
            )));
    }
}
