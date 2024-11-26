// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IVerifierFeeManager {}

interface IVerifierProxy {
    /**
     * @notice Verifies that the data encoded has been signed.
     * correctly by routing to the correct verifier, and bills the user if applicable.
     * @param payload The encoded data to be verified, including the signed
     * report.
     * @param parameterPayload Fee metadata for billing. For the current implementation this is just the abi-encoded fee token ERC-20 address.
     * @return verifierResponse The encoded report from the verifier.
     */
    function verify(
        bytes calldata payload,
        bytes calldata parameterPayload
    ) external payable returns (bytes memory verifierResponse);

    function s_feeManager() external view returns (IVerifierFeeManager);
}

interface IFeeManager {


    function getFeeAndReward(
        address subscriber,
        bytes memory unverifiedReport,
        address quoteAddress
    ) external returns (IAproOracleV2.Asset memory, IAproOracleV2.Asset memory, uint256);

    function i_linkAddress() external view returns (address);

    function i_nativeAddress() external view returns (address);

    function i_rewardManager() external view returns (address);
}

interface IAproOracleV2 {
     struct Report {
        bytes32 feedId;
        uint32 validFromTimestamp; 
        uint32 observationsTimestamp;
        uint192 nativeFee;
        uint192 linkFee;
        uint32 expiresAt;
        uint192 price;
        uint192 bid; 
        uint192 ask;
    }
    struct Price {
        uint192 value;
        int8 decimal;
        uint32 observeAt;
        uint32 expireAt;
    }
    struct Asset {
        address assetAddress;
        uint256 amount;
    }

    function verifyReportWithWrapNativeToken(
        bytes calldata payload
    ) external returns (bytes32, uint32, uint192);

    function getValidTimePeriod()
        external
        view
        returns (uint256 validTimePeriod);

    function updateReport(bytes calldata report) external;

    function getPrice(bytes32 id) external view returns (Price memory price);

    function getPriceUnsafe(
        bytes32 id
    ) external view returns (Price memory price);

    function getPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view returns (Price memory price);

    function getFeeAndReward(
        address subscriber,
        bytes memory unverifiedReport,
        address quoteAddress
    ) external returns (Asset memory, Asset memory, uint256);

    event ReadPrice(
        address masterToken,
        address quotaToken,
        uint256 masterPrice,
        uint256 quotaPrice
    );
}

interface IPriceReader {
    /// @notice Returns the period (in seconds) that a price feed is considered valid since its observe time
    function getValidTimePeriod()
        external
        view
        returns (uint256 validTimePeriod);

    function updateReport(bytes calldata report) external;

    function getPrice(
        bytes32 id
    ) external view returns (IAproOracleV2.Price memory price);

    function getPriceUnsafe(
        bytes32 id
    ) external view returns (IAproOracleV2.Price memory price);

    function getPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view returns (IAproOracleV2.Price memory price);
}
