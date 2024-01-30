// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
interface IIssuanceModule{
   event Issue(address _vault, address from, address[] _assets,uint256[] _amounts);
   event Redeem(address _vault,uint256[]  _assetsType,address[] _assets,uint256[]  _amounts);
   function issue(address _vault,address payable _from,address[] memory _assets,uint256[] memory _amounts) external payable;
   function redeem(address _vault,address payable _to,uint256[] memory _assetsType,address[] memory _assets,uint256[] memory _amounts) external;
   function redeemProxy(address _vault, uint256[] memory _assetsType,address[] memory _assets,uint256[] memory _amounts) external;
   function issueAndProxy(address _vault, address[] memory _assets,uint256[] memory _amounts) external payable;
}