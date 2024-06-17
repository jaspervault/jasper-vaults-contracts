// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IPoolModule {

    event Issue (
        address _vault,
        address _from,
        address _asset,
        uint256 _amount
    );
    
    event Deposit (
        address _from,
        uint256 _AssetAmount,
        uint256 _lpAmount
    );

    event Withdraw (
        address _to,
        uint256 _AssetAmount,
        uint256 _lpAmount
    );

    event WithdrawProfit (
        address profitAsset,
        address _from,
        uint256 _amount
    );

    event WithdrawPrincipal (
        address profitAsset,
        address _from,
        uint256 _amount
    );

}
