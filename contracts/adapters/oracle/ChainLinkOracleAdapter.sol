// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IOwnable} from "../../interfaces/internal/IOwnable.sol";
import {IChainLinkOracle} from "../../interfaces/external/IChainLinkOracle.sol";
import {IOracleAdapter} from "../../interfaces/internal/IOracleAdapter.sol";

contract ChainLinkOracleAdapter is IOracleAdapter,Initializable, UUPSUpgradeable {
    address public diamond;
    mapping(address => mapping(address => address)) public oralces;
    address public ethToken;
    address public usdToken;
    event  SetOralces(
        address _masterToken,
        address _quoteToken,
        address _oracle
    ); 
    modifier onlyOwner() {
        require(msg.sender == IOwnable(diamond).owner(), "only owner");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _diamond,
        address _ethToken,
        address _usdToken
    ) public initializer {
        diamond = _diamond;
        ethToken = _ethToken;
        usdToken = _usdToken;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setOralces(
        address _masterToken,
        address _quoteToken,
        address _oracle
    ) public onlyOwner {
        require(
            _quoteToken == ethToken || _quoteToken == usdToken,
            "ChainLinkOracleAdapter:quoteToken error"
        );
        oralces[_masterToken][_quoteToken] = _oracle;
        emit SetOralces(_masterToken, _quoteToken, _oracle);
    }

    function setOralceList(
        address[] memory _masterTokens,
        address[] memory _quoteTokens,
        address[] memory _oracle
    ) external onlyOwner {
        for (uint i; i < _quoteTokens.length; i++) {
            setOralces(_masterTokens[i], _quoteTokens[i], _oracle[i]);
        }
    }

    function read(
        address _masterToken,
        address _quoteToken
    ) external view returns (uint256) {
        uint256 price;
        if (_quoteToken == usdToken) {
            return getPriceByBase(_masterToken, usdToken);
        }
        if (_quoteToken == ethToken) {
            return getPriceByBase(_masterToken, ethToken);
        }
        (, price) = getPriceByUsd(_masterToken, _quoteToken);
        require(price !=0,"Invalid price");
        return price;
        //    if(status){
        //        return price;
        //    }else{
        //     //    revert("ChainLinkOracleAdapter:price not found");
        //       return 0;
        //    }
    }

    function getPriceByBase(
        address _masterToken,
        address _quoteToke
    ) internal view returns (uint256) {
        address masterOracle = oralces[_masterToken][_quoteToke];
        if(masterOracle == address(0)){
            return 0;
        }
        uint256 masterPrice = IChainLinkOracle(masterOracle).latestAnswer();
        uint256 masterDecimals = IChainLinkOracle(masterOracle).decimals();
        return masterPrice * 10 ** (18 - masterDecimals);
    }

    function getPriceByUsd(
        address _masterToken,
        address _quoteToken
    ) internal view returns (bool, uint256) {
        address masterOracle = oralces[_masterToken][usdToken];
        address quoteOracle = oralces[_quoteToken][usdToken];
        if (masterOracle == address(0) || quoteOracle == address(0)) {
            return getPriceByEth(_masterToken, _quoteToken);
        }
        return (true, getPrice(masterOracle, quoteOracle));
    }

    function getPriceByEth(
        address _masterToken,
        address _quoteToken
    ) internal view returns (bool, uint256) {
        address masterOracle = oralces[_masterToken][ethToken];
        address quoteOracle = oralces[_quoteToken][ethToken];
        if (masterOracle == address(0) || quoteOracle == address(0)) {
            return getPriceTransformEth(_masterToken, _quoteToken);
        }
        return (true, getPrice(masterOracle, quoteOracle));
    }

    function getPrice(
        address _materOracle,
        address _quoteOracle
    ) internal view returns (uint256) {
        uint256 masterPrice = IChainLinkOracle(_materOracle).latestAnswer();
        uint256 quotePrice = IChainLinkOracle(_quoteOracle).latestAnswer();
        uint256 masterDecimals = IChainLinkOracle(_materOracle).decimals();
        uint256 quoteDecimals = IChainLinkOracle(_quoteOracle).decimals();
        masterPrice = masterPrice * 10 ** (18 - masterDecimals);
        quotePrice = quotePrice * 10 ** (18 - quoteDecimals);
        return (masterPrice * 10 ** 18) / quotePrice;
    }

    function getPriceTransformEth(
        address _masterToken,
        address _quoteToken
    ) internal view returns (bool, uint256) {
        (bool status, uint256 price) = getPriceByTransform(
            _masterToken,
            _quoteToken,
            ethToken,
            usdToken
        );
        if (status) {
            return (true, price);
        } else {
            return getPriceTransformUsd(_masterToken, _quoteToken);
        }
    }

    function getPriceTransformUsd(
        address _masterToken,
        address _quoteToken
    ) internal view returns (bool, uint256) {
        return
            getPriceByTransform(_masterToken, _quoteToken, usdToken, ethToken);
    }

    function getPriceByTransform(
        address _masterToken,
        address _quoteToken,
        address _oneToken,
        address _twoToken
    ) internal view returns (bool, uint256) {
        address masterOracle = oralces[_masterToken][_oneToken];
        if (masterOracle == address(0)) {
            return (false, 0);
        }
        address quoteOracle = oralces[_quoteToken][_twoToken];
        if (quoteOracle == address(0)) {
            return (false, 0);
        }
        address transformOracle = oralces[ethToken][usdToken];

        if (_oneToken == ethToken) {
            uint256 quotePriceByEth = getPrice(quoteOracle, transformOracle);
            uint256 masterPrice = IChainLinkOracle(masterOracle).latestAnswer();
            uint256 masterDecimals = IChainLinkOracle(masterOracle).decimals();
            masterPrice = masterPrice * 10 ** (18 - masterDecimals);
            return (true, (masterPrice * 10 ** 18) / quotePriceByEth);
        } else {
            uint256 masterPriceByEth = getPrice(masterOracle, transformOracle);
            uint256 quotePrice = IChainLinkOracle(quoteOracle).latestAnswer();
            uint256 quoteDecimals = IChainLinkOracle(quoteOracle).decimals();
            quotePrice = quotePrice * 10 ** (18 - quoteDecimals);
            return (true, (masterPriceByEth * 10 ** 18) / quotePrice);
        }
    }
}
