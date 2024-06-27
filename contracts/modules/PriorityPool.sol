// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

import "../lib/PoolBase.sol";
import "../interfaces/internal/ILPToken.sol";
import "../interfaces/internal/IPoolModule.sol";
import "../interfaces/internal/IProfitService.sol";


contract PriorityPool is
    PoolBase
{
    using SafeMath for uint256;

    address public profitService;
    address public lpToken;
    uint256 public lastProfit;
    uint256 totalDepositAmount;
    mapping (address=> uint256) public addressDepositAmountMap;
    mapping (address=> uint256) public addressProfitMap;
    address[] addressProfitList;
    
    // profit asset WBTC ETH USDT <=> USDT
    address public profitAsset;

    function __PriorityPool_init(
        address _vault,
        address _diamond,
        address _asset,
        address _profitAsset,
        address _lpToken,
        address _profitService
        )public initializer {

        super.initialize(_vault,_diamond,_asset);
        lpToken = _lpToken;
        lastProfit = 0;
        // lastProfit
        profitService = _profitService;
        profitAsset = _profitAsset;
    }

    /**
     * depoist to vault 
     * @param _amount deposit asset amount include:ETH,USDT,WETH
     */
    function deposit(
        uint256 _amount
    ) payable external nonReentrant{

        // deposit to vault
        depositToVault(_amount);

        // mint LP Token USDTJ
        ILPToken(lpToken).mint(msg.sender, _amount);

        uint256 currentProfit = getCurrentProfit();

        // distribute this profit
        uint256 thisTimeProfit = currentProfit - lastProfit;

        bool isExist = false;
        for (uint256 index = 0; index < addressProfitList.length; index++) {
            address profitAddress = addressProfitList[index];
            uint256 addressDeposit = addressDepositAmountMap[profitAddress];
            uint256 addressProfit = addressProfitMap[profitAddress];
            addressProfitMap[profitAddress] = addressDeposit.mul(thisTimeProfit).div(totalDepositAmount).add(addressProfit);

            if(profitAddress == msg.sender) {
                isExist = true;
            }
        }

        if(isExist) {
            addressDepositAmountMap[msg.sender] += _amount;
        } else {
            addressProfitList.push(msg.sender);
            addressDepositAmountMap[msg.sender] = _amount;
            addressProfitMap[msg.sender] = 0;
        }

        totalDepositAmount += _amount;
        lastProfit  =  currentProfit;

        emit Deposit(msg.sender, _amount,_amount);

    }

    /**
     * withdraw  profit from vault 
     * @param _amount withdraw profit from vault
     */
    function withdrawProfit(
        uint256 _amount
    ) external nonReentrant{
        uint256 addressProfit = addressProfitMap[msg.sender];
        require(_amount <= addressProfit, "Insufficient profit");

        withdrawFromVault(profitAsset, msg.sender, _amount);
        addressProfitMap[msg.sender] -= _amount;
        
        emit WithdrawProfit(profitAsset, msg.sender, _amount);

    }


    /**
     * withdraw  principal from vault 
     * @param _amount withdraw principal from vault
     */
    function withdrawPrincipal(
        uint256 _amount
    ) external nonReentrant{

        uint256 addressDeposit = addressDepositAmountMap[msg.sender];
        require(_amount <= addressDeposit, "Insufficient amount");

        withdrawFromVault(asset, msg.sender, _amount);
        addressDepositAmountMap[msg.sender] -= _amount;

        ILPToken(lpToken).burnFrom(msg.sender, _amount);

        // mint LP Token
        emit WithdrawPrincipal(asset, msg.sender, _amount);

    }

    // Decimal
    function getCurrentProfit() internal view returns(uint256) {
        return IProfitService(profitService).currentProfit();
    }

    function getAddressProfit() external view returns(uint256) {
        return addressProfitMap[msg.sender];
    }

    fallback() external payable {
        // custom function code
    }

    receive() external payable {
        // custom function code
    }

}
