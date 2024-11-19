// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {IOwnable} from "./interfaces/internal/IOwnable.sol";
import {IOracleAdapter} from "./interfaces/internal/IOracleAdapter.sol";
import {IPriceOracle} from "./interfaces/internal/IPriceOracle.sol";
import {IOracleAdapterV2} from "./interfaces/internal/IOracleAdapterV2.sol";
import {IPlatformFacet} from "./interfaces/internal/IPlatformFacet.sol";
contract PriceOracle is Initializable, UUPSUpgradeable,IPriceOracle
     {
    address public diamond;
    address[] public oracles; //chainLink  coinbase  uniswap ...
    event SetOracles(address[] _addOracles, address[] _delOracles);
    modifier onlyOwner() {
        require(msg.sender == IOwnable(diamond).owner(), "only owner");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _diamond) public initializer {
        diamond = _diamond;
    }
    function setPrice(address _pyth,bytes[] calldata _priceUpdateData) external{
        require(IPlatformFacet(diamond).getIsVault(msg.sender),"PriceOracle:role error");  
        uint fee = IPyth(_pyth).getUpdateFee(_priceUpdateData);
        IPyth(_pyth).updatePriceFeeds{ value: fee }(_priceUpdateData);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setOracles(
        address[] memory _addOracles,
        address[] memory _delOracles
    ) external onlyOwner {
        for (uint256 i; i < _addOracles.length; i++) {
            require(
                _addOracles[i] != address(0),
                "PriceOracle:invalid address"
            );
            oracles.push(_addOracles[i]);
        }
        for (uint256 i; i < _delOracles.length; i++) {
            for (uint j; j < oracles.length; j++) {
                if (_delOracles[i] == oracles[j]) {
                    oracles[j] = oracles[oracles.length - 1];
                    oracles.pop();
                }
            }
        }
        emit SetOracles(_addOracles, _delOracles);
    }

    function getPrice(
        address _masterToken,
        address _quoteToken
    ) external view returns (uint256) {
        return getPriceByMedian(_masterToken, _quoteToken);
    }

    function getUSDPrice(address _token) external view returns (uint256) {
        return
            getPriceByMedian(
                _token,
                0x0000000000000000000000000000000000000001
            );
    }

    //weighted average
    function getPriceByAverage(
        address _masterToken,
        address _quoteToken
    ) public view returns (uint256) {
        require(oracles.length >= 3, "PriceOracle:oracle to low");
        uint256[] memory priceList = getPriceList(_masterToken, _quoteToken);
        uint256 countLen;
        uint256 totalPrice;
        for (uint i; i < priceList.length; i++) {
            if (priceList[i] != 0) {
                totalPrice += priceList[i];
                countLen++;
            }
        }
        require(countLen != 0, "PriceOracle:price not found");
        uint256 price = totalPrice / countLen;
        require(price != 0, "PriceOracle:price not found");
        return price;
    }

    //Take the middle price from the price list
    function getPriceByMedian(
        address _masterToken,
        address _quoteToken
    ) public view returns (uint256) {
        uint256[] memory priceList = getPriceList(_masterToken, _quoteToken);
        uint256 index = priceList.length / 2;
        require(priceList[index] != 0, "PriceOracle:price not found");
        return priceList[index];
    }

    function getPriceList(
        address _masterToken,
        address _quoteToken
    ) internal view returns (uint256[] memory) {
        uint256[] memory priceList = new uint256[](oracles.length);
        for (uint i; i < oracles.length; i++) {
            priceList[i] = IOracleAdapter(oracles[i]).read(
                _masterToken,
                _quoteToken
            );
        }
        priceList = sortArray(priceList);
        return priceList;
    }

    function sortArray(
        uint256[] memory _array
    ) internal pure returns (uint256[] memory) {
        // Sort the _array
        for (uint i = 0; i < _array.length; i++) {
            for (uint j = i + 1; j < _array.length; j++) {
                if (_array[i] > _array[j]) {
                    uint temp = _array[i];
                    _array[i] = _array[j];
                    _array[j] = temp;
                }
            }
        }
        return _array;
    }
    receive() external payable {}

    function getPriceByChainLinkRoundIDList(
        address _masterToken,
        address _quoteToken,
        uint80[] calldata _chainLinkIDList
    ) external view returns (uint256) {
        return getPriceByMedian(_masterToken, _quoteToken);
    }

    function getUSDPriceSpecifyOracle(address _token, uint index) external view returns (uint256){
        return IOracleAdapter(oracles[index]).read(_token, 0x0000000000000000000000000000000000000001);
    }
    function getPriceSpecifyOracle(address _assetOne, address _assetTwo, uint index) external view returns (uint256){
        return IOracleAdapter(oracles[index]).read(_assetOne, _assetTwo);
    }
    function getHistoryPrice(
        address _assetOne,
        uint256 _index,
        bytes[] memory _data
    ) external returns (HistoryPrice[] memory price){
        return  IOracleAdapterV2(oracles[_index]).readHistoryPrice(_assetOne, _data);
    }
    function  readByRoundID(address _masterToken, uint80 _roundId, uint _index) public view returns(RoundData memory ){
    }
}
