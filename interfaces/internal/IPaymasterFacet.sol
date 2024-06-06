// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IPaymasterFacet {

    struct DepositInfo {
        address wallet;
        string protocol;
        uint256 positionType;
        address sendAsset;
        address receiveAsset;
        uint256 adapterType;
        uint256 amountIn;
        uint256 amountLimit;
        uint256 approveAmount;
        bytes adapterData;
    }
    event SetOpenValidMiner(bool _openValidMiner);
    event SetMinerList(address[] _addMiners, address[] _delMiners);
    event SetQuotaWhiteList(uint8 _type, address _target, uint256 _amount);
    event SetWalletPaymasterBalance(
        address _wallet,
        uint256 _amount,
        bool _type
    );

    function setWalletPaymasterBalance(
        address _wallet,
        uint256 _amount,
        bool _type
    ) external;

    function getWalletPaymasterBalance(
        address _wallet
    ) external view returns (uint256);

    function setPayer(address _payer) external;

    function getPayer() external view returns (address);

    function setQuotaWhiteList(
        uint8 _type,
        address _target,
        uint256 _amount
    ) external;

    function getQuota(address _target) external view returns (uint256);

    function setOpenValidMiner(bool _openValidMiner) external;

    function getOpenValidMiner() external view returns (bool);

    function setMinerList(
        address[] memory _addMiners,
        address[] memory _delMiners
    ) external;

    function getMinerStatus(address _miner) external view returns (bool);
    function setQuotaLimit(address _payer, uint _limit) external ;
    function getQuotaLimit(address _payer) external view returns (uint _limit) ;
    function setFuncFeeWhitelist(bytes4  func, FreeGasFuncType _type) external ;
    function getFuncFeeWhitelist(bytes4  func) external view returns (FreeGasFuncType _type) ;
    enum FreeGasFuncType {
        None,
        Normal,
        Issuse
    }
}
