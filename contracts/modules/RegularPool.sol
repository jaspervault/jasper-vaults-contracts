// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "hardhat/console.sol";

import "../lib/PoolBase.sol";
import "../interfaces/internal/ILPToken.sol";
import "../interfaces/internal/IPoolModule.sol";
import "../interfaces/internal/IReader.sol";

contract RegularPool is PoolBase
{
    using SafeMath for uint256;
    address public reader;
    address public lpToken;
    uint256 public lastProfit;
    uint256 totalDepositAmount;
    mapping (address=> uint256) public addressDepositAmountMap;
    mapping (address=> uint256) public addressLPMap;
    address[] addressDepositList;
    uint256 totalWithdrawAmount;

    function __RegularPool_init(
        address _vault,
        address _diamond,
        address _asset,
        address _lpToken,
        address _reader
        )public initializer {

        super.initialize(_vault,_diamond,_asset);
        lpToken = _lpToken;
        lastProfit = 0;

        // lastProfit
        reader = _reader;
    }

    /**
     * depoist to vault 
     * @param _assetAmount deposit asset amount include:ETH,USDT,WETH
     */
    function deposit(
        uint256 _assetAmount
    ) payable  external nonReentrant {

        // validate params
        require(_assetAmount > 0, "deposit amount should larger than 0");

        // deposit to vault
        depositToVault(_assetAmount);

        // calculate the lp token
        uint256 currentAmount = getCurrentAmount();
        uint lpAmount = currentAmount > 0 ? totalDepositAmount.mul(_assetAmount).div(currentAmount) : _assetAmount;
        
        // mint LP Token XJ
        ILPToken(lpToken).mint(msg.sender, lpAmount);

        // record the LP and Deposit Data
        addressLPMap[msg.sender] += lpAmount;
        totalDepositAmount += _assetAmount;

        addressDepositAmountMap[msg.sender] += _assetAmount;
        addressDepositList.push(msg.sender);

        emit Deposit(msg.sender, _assetAmount,lpAmount);

    }

    /**
     * withdraw from vault include:ETH,USDT,WETH
     * @param _lpAmount LP amount amount 
     */
    function withdraw(
        uint256 _lpAmount
    ) external nonReentrant{

        // validate params
        uint256 currentAmount = getCurrentAmount();
        require(currentAmount > 0, "current amount should larger than 0");

        // burn LP Token
        ILPToken(lpToken).burnFrom(msg.sender, _lpAmount);

        // calculate withdraw amount
        uint256 depositAmount = addressDepositAmountMap[msg.sender];
        uint256 assetAmount = depositAmount.mul(currentAmount).div(totalDepositAmount);

        addressLPMap[msg.sender] -= _lpAmount;
        // withdrawFromVault(asset, msg.sender,assetAmount);

        totalWithdrawAmount += assetAmount;
        
        emit Withdraw(msg.sender,assetAmount,_lpAmount);

    }


    function setFuncBlackList(address _blacker, bool _type) external onlyOwner{

        IVaultFacet vaultFacet = IVaultFacet(diamond);
        vaultFacet.setFuncBlackList(
            _blacker,
            bytes4(keccak256("setVaultType(address,uint256)")),
            _type
        );

        vaultFacet.setFuncBlackList(
            _blacker,
            bytes4(keccak256("function setModules(address[] memory,bool[] memory)")),
            _type
        );

    }

    function setFuncWhiteList(address _whiter, bool _type) external onlyOwner{
        IVaultFacet vaultFacet = IVaultFacet(diamond);
        vaultFacet.setFuncWhiteList(
            _whiter,
            bytes4(
                keccak256(
                    "function withdraw(uint256)"
                )
            ),
            _type
        );
        vaultFacet.setFuncWhiteList(
            _whiter,
            bytes4(
                keccak256(
                    "liquidateOption(uint8,uint64,uint8,uint256,uint256)"
                )
            ),
            _type
        );
        vaultFacet.setFuncWhiteList(
            _whiter,
            bytes4(
                keccak256(
                    "setPrice(address,bytes[])"
                )
            ),
            _type
        );
    }


    function getCurrentAmount() internal view returns(uint256) {
        return IReader(reader).getVaultAmount(vault);
    }

    function getSumAmounts() external view returns(uint256,uint256,uint256){

        uint256 currentAmount = getCurrentAmount();
        return (currentAmount,totalDepositAmount,totalWithdrawAmount);
    }

    fallback() external payable {
        // custom function code
    }

    receive() external payable {
        // custom function code
    }

}
