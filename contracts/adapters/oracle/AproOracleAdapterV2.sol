// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.12;
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import {IOwnable} from "../../interfaces/internal/IOwnable.sol";
// import {IAproOracle} from "../../interfaces/external/IAproOracle.sol";
// import {IOracleAdapter} from "../../interfaces/internal/IOracleAdapter.sol";
// import {IOracleAdapterV2} from "../../interfaces/internal/IOracleAdapterV2.sol";

// contract AproOracleAdapter is IOracleAdapter,Initializable, UUPSUpgradeable,IOracleAdapterV2 {
//     address public diamond;
//     mapping(address => mapping(address => address)) public oralces;
//     address public ethToken;
//     address public usdToken;
//     event  SetOralces(
//         address _masterToken,
//         address _quoteToken,
//         address _oracle
//     ); 
//     modifier onlyOwner() {
//         require(msg.sender == IOwnable(diamond).owner(), "only owner");
//         _;
//     }

//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() {
//         _disableInitializers();
//     }

//     function initialize(
//         address _diamond,
//         address _ethToken,
//         address _usdToken
//     ) public initializer {
//         diamond = _diamond;
//         ethToken = _ethToken;
//         usdToken = _usdToken;
//     }

//     function _authorizeUpgrade(
//         address newImplementation
//     ) internal override onlyOwner {}

//     function setOralces(
//         address _masterToken,
//         address _quoteToken,
//         address _oracle
//     ) public onlyOwner {
//         require(
//             _quoteToken == ethToken || _quoteToken == usdToken,
//             "AproOracleAdapter:quoteToken error"
//         );
//         oralces[_masterToken][_quoteToken] = _oracle;
//         emit SetOralces(_masterToken, _quoteToken, _oracle);
//     }

//     function setOralceList(
//         address[] memory _masterTokens,
//         address[] memory _quoteTokens,
//         address[] memory _oracle
//     ) external onlyOwner {
//         for (uint i; i < _quoteTokens.length; i++) {
//             setOralces(_masterTokens[i], _quoteTokens[i], _oracle[i]);
//         }
//     }

//    function readV2(address _masterToken,address _quoteToken,uint256 _publishTime,bytes memory _data) external  returns(uint256 price){
//         IAproOracle.SummaryAproData memory roundData = decode(_data);
//         return getPriceByBaseV2(_masterToken, _quoteToken,_publishTime,roundData);
//    }
//     function read(
//         address _masterToken,
//         address _quoteToken
//     ) external view returns (uint256) {
//         uint256 price;
//         if (_quoteToken == usdToken) {
//             return getPriceByBase(_masterToken, usdToken);
//         }
//         if (_quoteToken == ethToken) {
//             return getPriceByBase(_masterToken, ethToken);
//         }
//         (, price) = getPriceByUsd(_masterToken, _quoteToken);
//         require(price !=0,"Invalid price");
//         return price;
//     }
    
//     function getPriceByBase(
//         address _masterToken,
//         address _quoteToke
//     ) internal view returns (uint256) {
//         address masterOracle = oralces[_masterToken][_quoteToke];
//         if(masterOracle == address(0)){
//             revert("AproOracleAdapter:masterOracle miss");
//             return 0;
//         }
//         require(IAproOracle(masterOracle).latestAnswer()>0,"AproOracleAdapter:price <0");
//         uint256 masterPrice = uint(IAproOracle(masterOracle).latestAnswer());
//         uint256 masterDecimals = IAproOracle(masterOracle).decimals();
//         return masterPrice * 10 ** (18 - masterDecimals);
//     }

//     function getPriceByUsd(
//         address _masterToken,
//         address _quoteToken
//     ) internal view returns (bool, uint256) {
//         address masterOracle = oralces[_masterToken][usdToken];
//         address quoteOracle = oralces[_quoteToken][usdToken];
//         if (masterOracle == address(0) || quoteOracle == address(0)) {
//             return getPriceByEth(_masterToken, _quoteToken);
//         }
//         return (true, getPrice(masterOracle, quoteOracle));
//     }

//     function getPriceByEth(
//         address _masterToken,
//         address _quoteToken
//     ) internal view returns (bool, uint256) {
//         address masterOracle = oralces[_masterToken][ethToken];
//         address quoteOracle = oralces[_quoteToken][ethToken];
//         if (masterOracle == address(0) || quoteOracle == address(0)) {
//             return getPriceTransformEth(_masterToken, _quoteToken);
//         }
//         return (true, getPrice(masterOracle, quoteOracle));
//     }

//     function getPrice(
//         address _materOracle,
//         address _quoteOracle
//     ) internal view returns (uint256) {
//         require(IAproOracle(_materOracle).latestAnswer()>0,"AproOracleAdapter:price <0");
//         uint256 masterPrice = uint(IAproOracle(_materOracle).latestAnswer());
//         require(IAproOracle(_quoteOracle).latestAnswer()>0,"AproOracleAdapter:price <0");
//         uint256 quotePrice = uint(IAproOracle(_quoteOracle).latestAnswer());
//         uint256 masterDecimals = IAproOracle(_materOracle).decimals();
//         uint256 quoteDecimals = IAproOracle(_quoteOracle).decimals();
//         masterPrice = masterPrice * 10 ** (18 - masterDecimals);
//         quotePrice = quotePrice * 10 ** (18 - quoteDecimals);
//         return (masterPrice * 10 ** 18) / quotePrice;
//     }

//     function getPriceTransformEth(
//         address _masterToken,
//         address _quoteToken
//     ) internal view returns (bool, uint256) {
//         (bool status, uint256 price) = getPriceByTransform(
//             _masterToken,
//             _quoteToken,
//             ethToken,
//             usdToken
//         );
//         if (status) {
//             return (true, price);
//         } else {
//             return getPriceTransformUsd(_masterToken, _quoteToken);
//         }
//     }

//     function getPriceTransformUsd(
//         address _masterToken,
//         address _quoteToken
//     ) internal view returns (bool, uint256) {
//         return
//             getPriceByTransform(_masterToken, _quoteToken, usdToken, ethToken);
//     }

//     function getPriceByTransform(
//         address _masterToken,
//         address _quoteToken,
//         address _oneToken,
//         address _twoToken
//     ) internal view returns (bool, uint256) {
//         address masterOracle = oralces[_masterToken][_oneToken];
//         if (masterOracle == address(0)) {
//             return (false, 0);
//         }
//         address quoteOracle = oralces[_quoteToken][_twoToken];
//         if (quoteOracle == address(0)) {
//             return (false, 0);
//         }
//         address transformOracle = oralces[ethToken][usdToken];

//         if (_oneToken == ethToken) {
//             uint256 quotePriceByEth = getPrice(quoteOracle, transformOracle);
//             require(IAproOracle(masterOracle).latestAnswer()>0,"AproOracleAdapter:price <0");
//             uint256 masterPrice =uint(IAproOracle(masterOracle).latestAnswer());
//             uint256 masterDecimals = IAproOracle(masterOracle).decimals();
//             masterPrice = masterPrice * 10 ** (18 - masterDecimals);
//             return (true, (masterPrice * 10 ** 18) / quotePriceByEth);
//         } else {
//             uint256 getPriceV2masterPriceByEth = getPrice(masterOracle, transformOracle);
//             require(IAproOracle(quoteOracle).latestAnswer()>0,"AproOracleAdapter:price <0");
//             uint256 quotePrice = uint(IAproOracle(quoteOracle).latestAnswer());
//             uint256 quoteDecimals = IAproOracle(quoteOracle).decimals();
//             quotePrice = quotePrice * 10 ** (18 - quoteDecimals);
//             return (true, (masterPriceByEth * 10 ** 18) / quotePrice);
//         }
//     }
//     function decode(bytes memory _data)internal returns(IAproOracle.SummaryAproData memory roundData ){
//         return abi.decode(_data, (IAproOracle.SummaryAproData));
//     }
//     function getPriceByBaseV2(
//         address _masterToken, address _quoteToken, uint256 _publishTime, IAproOracle.SummaryAproData memory _roundData
//     ) internal view returns (uint256 _price) {
//         (bytes32 feedId, uint32 timestamp, uint192 verifiedPrice) = verifyReportWithWrapNativeToken(payload);
//     }
//     function latestRoundData(address _masterToken, address _quoteToken)public view returns(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
//         address quoteOracle = oralces[_masterToken][_quoteToken]; 
//         require(quoteOracle!=address(0),"AproOracleAdapter: oracle miss");
//         return IAproOracle(quoteOracle).latestRoundData();
//     }
//     function getRoundData(address _masterToken, address _quoteToken, uint80 _roundId)public view returns(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
//         address quoteOracle = oralces[_masterToken][_quoteToken]; 
//         require(quoteOracle!=address(0),"AproOracleAdapter: oracle miss");
//         return IAproOracle(quoteOracle).getRoundData(_roundId);
//     }
// }
