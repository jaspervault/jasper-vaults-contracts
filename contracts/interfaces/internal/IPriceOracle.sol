// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IPriceOracle {
    /*
     * @param _assetOne         Address of first asset in pair
     * @param _assetTwo         Address of second asset in pair
     * @return                 one/two  Price of asset pair to 18 decimals of precision
     */
    function getPrice(
        address _assetOne,
        address _assetTwo
    ) external view returns (uint256);

    function getUSDPrice(address _token) external view returns (uint256);
}
