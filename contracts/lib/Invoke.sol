// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IVault} from  "../interfaces/internal/IVault.sol";

import "hardhat/console.sol";

library Invoke {
    // using SafeMath for uint256;
    function invokeApprove(IVault _vault,address _token,address _spender,uint256 _amount) internal {
         bytes memory _calldata = abi.encodeWithSignature("approve(address,uint256)", _spender, _amount);
         _vault.execute(_token, 0, _calldata);
    }

    function invokeApproveNft(IVault _vault,address _nft,address _to, uint256 _tokenId) internal{
        bytes memory _calldata = abi.encodeWithSignature("approve(address,uint256)", _to, _tokenId);
        _vault.execute(_nft, 0, _calldata);
    }

    function invokeTransferNft(IVault _vault,address _nft,address _to, uint256 _tokenId) internal {
        bytes memory _calldata = abi.encodeWithSignature("transferFrom(address,address,uint256)",address(_vault),_to, _tokenId);
        _vault.execute(_nft, 0, _calldata);       
    }
    function invokeTransfer(IVault _vault,address _token,address _to,uint256 _amount) internal{

        // console.log("sol 01 invokeTransfer ... %s ",_token);
        if(_amount>0){

          // console.log("sol 02 invokeTransfer ... %s - %s -%s",_to, _amount,address(_vault));
          
          bytes memory _calldata = abi.encodeWithSignature("transfer(address,uint256)", _to, _amount);
          console.logBytes(_calldata);

          _vault.execute(_token, 0, _calldata);
          // _vault.owner();
        //   bytes memory result = _vault.execute(_token, 0, _calldata);
        //   console.log("xxl 00 1");
        //   console.logBytes(result);
        }
    }
    function invokeTransferFrom(IVault _vault,address _token, address from, address _to,uint256 _amount) internal{
        if(_amount>0){
          bytes memory _calldata = abi.encodeWithSignature("transferFrom(address,address,uint256)", from, _to, _amount);
          _vault.execute(_token, 0, _calldata);
        }
    }
    
    function invokeUnwrapWETH(IVault _vault,address _weth,uint256 _amount) internal {
        bytes memory  _calldata = abi.encodeWithSignature("withdraw(uint256)", _amount);
        _vault.execute(_weth, 0, _calldata);
    }

    function invokeWrapWETH(IVault _vault,address _weth,uint256 _amount) internal{
        bytes memory  _calldata = abi.encodeWithSignature("deposit()");
        _vault.execute(_weth, _amount, _calldata);
    }

    function invokeTransferEth(IVault _vault,address _to, uint256 _amount) internal {
        // invokeWrapWETH(_vault,_weth,_amount);       
        // invokeTransfer(_vault,_weth,address(this),_amount);
        //  bytes memory  _calldata = abi.encodeWithSignature("withdraw(uint256)", _amount);
        //  (bool success, )=address(this).call(_calldata);
        //  require(success,"vault:withdraw eth fail");
        //  (success,)= _to.call{value:_amount}("");
        //  require(success,"vault:tranfer eth fail");
        bytes memory func;
        _vault.execute(_to,_amount, func);
    }
}