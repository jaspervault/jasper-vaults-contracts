// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IOwnable} from "../../interfaces/internal/IOwnable.sol";
import {IAproOracle} from "../../interfaces/external/IAproOracle.sol";
import {IPriceReader, IAproOracleV2, IVerifierProxy, IFeeManager} from "../../interfaces/external/IAproOracleV2.sol";
import {IOracleAdapter} from "../../interfaces/internal/IOracleAdapter.sol";
import {IOracleAdapterV2} from "../../interfaces/internal/IOracleAdapterV2.sol";
import {IPriceOracle} from "../../interfaces/internal/IPriceOracle.sol";

contract AproOracleAdapterV2 is
    IOracleAdapter,
    Initializable,
    UUPSUpgradeable,
    IOracleAdapterV2
{
    address public diamond;
    mapping(address => mapping(address => address)) public oralces;
    address public ethToken;
    address public usdToken;
    mapping(address => mapping(address => bytes32)) public pythIDs;
    mapping(address => uint256) public decimals;
    IVerifierProxy public s_verifierProxy;
    address operator;

    event SetOralces(
        address _masterToken,
        address _quoteToken,
        bytes32 _oracle
    );
    modifier onlyOwner() {
        // require(msg.sender == IOwnable(diamond).owner(), "only owner");
        require(msg.sender == operator, "only owner");
        _;
    }
    modifier onlyOperator() {
        require(msg.sender == operator, "only operator");
        _;
    }
    receive() external payable {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }


    function initialize(
        address _diamond,
        address _ethToken,
        address _usdToken,
        address _operator,
        address _verifierProxy
    ) public initializer {
        diamond = _diamond;
        ethToken = _ethToken;
        usdToken = _usdToken;
        operator = _operator;
        s_verifierProxy = IVerifierProxy(_verifierProxy);
    }
    event SetDecimals(address _token, uint256 _decimal);
    function setDecimals(address _token, uint256 _decimal) external onlyOperator  {
        decimals[_token] = _decimal;
        emit SetDecimals(_token, _decimal);
    }
    event SetVerifierProxy(address _operator);
    function setVerifierProxy(address _verifierProxy) external onlyOperator {
        require(operator == msg.sender, "AproOracleAdapter:only operator");
        s_verifierProxy = IVerifierProxy(_verifierProxy);
        emit SetVerifierProxy(_verifierProxy);
    }
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setOralcesIds(
        address _masterToken,
        address _quoteToken,
        bytes32 _id
    ) public onlyOperator {
        require(
            _quoteToken == ethToken || _quoteToken == usdToken,
            "AproOracleAdapter:quoteToken set error"
        );
        pythIDs[_masterToken][_quoteToken] = _id;
        emit SetOralces(_masterToken, _quoteToken, _id);
    }

   function setOralceList(
        address[] memory _masterTokens,
        address[] memory _quoteTokens,
        bytes32[] memory _ids
    ) external  onlyOperator{
        require(operator == msg.sender, "AproOracleAdapter:only operator");
        for (uint i; i < _quoteTokens.length; i++) {
            require(
            _quoteTokens[i] == ethToken || _quoteTokens[i] == usdToken,
            "AproOracleAdapter:quoteToken set error"
            );
            pythIDs[_masterTokens[i]][_quoteTokens[i]] = _ids[i];
            emit SetOralces(_masterTokens[i], _quoteTokens[i], _ids[i]);
        }
    }

    function readPrice(bytes32 feedId) public view returns (uint price) {
        // Read the current price from a price feed.
        // Note: this transactions may failed with PriceFeedExpire or PriceFeedNotFound error
        IAproOracleV2.Price memory nowPrice = IPriceReader(
            address(s_verifierProxy)
        ).getPriceUnsafe(feedId);
        require(nowPrice.value > 0, "IAproOracleV2:price less 0");
        uint32 tempExpo = nowPrice.decimal < 0
            ? uint32(uint8(-nowPrice.decimal))
            : uint32(uint8(nowPrice.decimal));
        uint256 expo = uint256(tempExpo);
        price = price * 10 ** (18 - expo);
        return price;
    }

    function read(
        address _masterToken,
        address _quoteToken
    ) external view returns (uint256) {
        if (_quoteToken == usdToken) {
            bytes32 priceId = pythIDs[_masterToken][_quoteToken];
            require(
                priceId != bytes32(0),
                "IAproOracleV2:_masterToken priceId miss"
            );
            return readPrice(priceId);
        } else {
            bytes32 priceId = pythIDs[_masterToken][usdToken];
            require(
                priceId != bytes32(0),
                "IAproOracleV2:_masterToken priceId miss"
            );
            uint masterTokenPrice = readPrice(priceId);

            priceId = pythIDs[_quoteToken][usdToken];
            require(
                priceId != bytes32(0),
                "IAproOracleV2:_quoteToken priceId miss"
            );
            uint quotaTokenPrice = readPrice(priceId);
            return (masterTokenPrice * 1 ether) / quotaTokenPrice;
        }
    }



    // Main function to read history price
    function readHistoryPrice(
        address _masterToken,
        bytes[] memory _data
    ) external  returns (IPriceOracle.HistoryPrice[] memory historyPrice) {
        uint len = _data.length;
        historyPrice = new IPriceOracle.HistoryPrice[](len);
        for (uint i; i < len; i++) {
            // Report verification fees
            IFeeManager feeManager = IFeeManager(
                address(s_verifierProxy.s_feeManager())
            );
            address feeTokenAddress = feeManager.i_nativeAddress();

            //decode the report from the payload
            (
                ,
                /* bytes32[3] reportContextData */ bytes memory reportData,
                ,
                ,

            ) = abi.decode(
                    _data[i],
                    (bytes32[3], bytes, bytes32[], bytes32[], bytes32)
                );
            (IAproOracleV2.Asset memory fee, , ) = feeManager.getFeeAndReward(
                address(this),
                reportData,
                feeTokenAddress
            );

            // Verify the report
            bytes memory verifiedReportData = s_verifierProxy.verify{
                value: fee.amount
            }(_data[i], abi.encode(feeTokenAddress));
            // uint256 change;
            // unchecked {
            //     //msg.value is always >= to fee.amount
            //     change =fee.amount - fee.amount;
            // }
            // if (change != 0) {
            //     payable(msg.sender).transfer(change);
            // }
            // Decode verified report data into a Report struct
            IAproOracleV2.Report memory verifiedReport = abi.decode(
                verifiedReportData,
                (IAproOracleV2.Report)
            );
            require(verifiedReport.feedId == pythIDs[_masterToken][usdToken], "PythOracleAdapter:_masterToken priceIDs missMatch");
            historyPrice[i].price = getPriceByPriceReport(_masterToken,verifiedReport);
            historyPrice[i].timestamp = verifiedReport.observationsTimestamp;
        }
        return historyPrice;
    }
    function getPriceByPriceReport(address token, IAproOracleV2.Report memory verifiedReport) public view returns(uint price){
        require(verifiedReport.price > 0, "IAproOracleV2:price less 0");
        uint256 tempExpo = decimals[token] == 0
            ? 18
            : decimals[token];
        uint256 expo = tempExpo;
        price = verifiedReport.price * 10 ** (18 - expo);
    }
    function verifyAndReadLatestPrice(bytes calldata payload) public returns( IAproOracleV2.Price memory price){
        IFeeManager feeManager = IFeeManager(address(s_verifierProxy.s_feeManager()));
        address feeTokenAddress = feeManager.i_nativeAddress();
        (/* bytes32[3] reportContextData */ , bytes memory reportData,,,) = abi
        .decode(payload, (bytes32[3], bytes, bytes32[], bytes32[], bytes32));
        (IAproOracleV2.Asset memory fee, ,) = feeManager.getFeeAndReward(
            address(this),
            reportData,
            feeTokenAddress
        );
        // Verify the report
        bytes memory verifiedReportData = s_verifierProxy.verify{value: fee.amount}(
            payload,
            abi.encode(feeTokenAddress)
        );
        IAproOracleV2.Report memory verifiedReport = abi.decode(verifiedReportData, (IAproOracleV2.Report));
        // verifiedReport.priceId
        return IPriceReader(address(s_verifierProxy)).getPriceNoOlderThan(verifiedReport.feedId, 60);
    }
    function setPrice(bytes[] calldata payloads) public {
        for(uint i;i<payloads.length;i++){
            IFeeManager feeManager = IFeeManager(address(s_verifierProxy.s_feeManager()));
            address feeTokenAddress = feeManager.i_nativeAddress();
            (/* bytes32[3] reportContextData */ , bytes memory reportData,,,) = abi.decode(payloads[i], (bytes32[3], bytes, bytes32[], bytes32[], bytes32));
              (IAproOracleV2.Asset memory fee, , ) = feeManager.getFeeAndReward(
                address(this),
                reportData,
                feeTokenAddress
            );
            s_verifierProxy.verify{value: fee.amount}(payloads[i],abi.encode(feeTokenAddress));
        }
    }

}
