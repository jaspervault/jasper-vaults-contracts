// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
interface IOwnable {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}
/// @title The ConfirmedOwner contract
/// @notice A contract with helpers for basic contract ownership.
contract ConfirmedOwnerWithProposal is IOwnable {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    // solhint-disable-next-line gas-custom-errors
    require(newOwner != address(0), "Cannot set owner to zero");

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /// @notice Allows an owner to begin transferring ownership to a new address.
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /// @notice Allows an ownership transfer to be completed by the recipient.
  function acceptOwnership() external override {
    // solhint-disable-next-line gas-custom-errors
    require(msg.sender == s_pendingOwner, "Must be proposed owner");

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /// @notice Get the current owner
  function owner() public view override returns (address) {
    return s_owner;
  }

  /// @notice validate, transfer ownership, and emit relevant events
  function _transferOwnership(address to) private {
    // solhint-disable-next-line gas-custom-errors
    require(to != msg.sender, "Cannot transfer to self");

    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /// @notice validate access
  function _validateOwnership() internal view {
    // solhint-disable-next-line gas-custom-errors
    require(msg.sender == s_owner, "Only callable by owner");
  }

  /// @notice Reverts if called by anyone other than the contract owner.
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}


/// @title The ConfirmedOwner contract
/// @notice A contract with helpers for basic contract ownership.
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

abstract contract TypeAndVersionInterface{
  function typeAndVersion()
    external
    pure
    virtual
    returns (string memory);
}

contract AproStructs {

    struct Price {
        uint192 value;
        int8 decimal;
        uint32 observeAt;
        uint32 expireAt;
    }
}
interface AccessControllerInterface {
  function hasAccess(address user, bytes calldata data) external view returns (bool);
}




interface IPriceReader {

    /// @notice Returns the period (in seconds) that a price feed is considered valid since its observe time
    function getValidTimePeriod() external view returns (uint256 validTimePeriod);

    function updateReport(bytes calldata report) external;

    function getPrice(
        bytes32 id
    ) external view returns (AproStructs.Price memory price);

    function getPriceUnsafe(
        bytes32 id
    ) external view returns (AproStructs.Price memory price);

    function getPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view returns (AproStructs.Price memory price);

}


  


interface IVerifier is IERC165 {
  /**
   * @notice Verifies that the data encoded has been signed
   * correctly by routing to the correct verifier.
   * @param signedReport The encoded data to be verified.
   * @param sender The address that requested to verify the contract.
   * This is only used for logging purposes.
   * @dev Verification is typically only done through the proxy contract so
   * we can't just use msg.sender to log the requester as the msg.sender
   * contract will always be the proxy.
   * @return verifierResponse The encoded verified response.
   */
  function verify(bytes calldata signedReport, address sender) external returns (bytes memory verifierResponse);

  /**
   * @notice sets offchain reporting protocol configuration incl. participating oracles
   * @param feedId Feed ID to set config for
   * @param signers addresses with which oracles sign the reports
   * @param offchainTransmitters CSA key for the ith Oracle
   * @param f number of faulty oracles the system can tolerate
   * @param onchainConfig serialized configuration used by the contract (and possibly oracles)
   * @param offchainConfigVersion version number for offchainEncoding schema
   * @param offchainConfig serialized configuration used by the oracles exclusively and only passed through the contract
   * @param recipientAddressesAndWeights the addresses and weights of all the recipients to receive rewards
   */
  function setConfig(
    bytes32 feedId,
    address[] memory signers,
    bytes32[] memory offchainTransmitters,
    uint8 f,
    bytes memory onchainConfig,
    uint64 offchainConfigVersion,
    bytes memory offchainConfig,
    Common.AddressAndWeight[] memory recipientAddressesAndWeights
  ) external;

  /**
   * @notice identical to `setConfig` except with args for sourceChainId and sourceAddress
   * @param feedId Feed ID to set config for
   * @param sourceChainId Chain ID of source config
   * @param sourceAddress Address of source config Verifier
   * @param newConfigCount Param to force the new config count
   * @param signers addresses with which oracles sign the reports
   * @param offchainTransmitters CSA key for the ith Oracle
   * @param f number of faulty oracles the system can tolerate
   * @param onchainConfig serialized configuration used by the contract (and possibly oracles)
   * @param offchainConfigVersion version number for offchainEncoding schema
   * @param offchainConfig serialized configuration used by the oracles exclusively and only passed through the contract
   * @param recipientAddressesAndWeights the addresses and weights of all the recipients to receive rewards
   */
  function setConfigFromSource(
    bytes32 feedId,
    uint256 sourceChainId,
    address sourceAddress,
    uint32 newConfigCount,
    address[] memory signers,
    bytes32[] memory offchainTransmitters,
    uint8 f,
    bytes memory onchainConfig,
    uint64 offchainConfigVersion,
    bytes memory offchainConfig,
    Common.AddressAndWeight[] memory recipientAddressesAndWeights
  ) external;

  /**
   * @notice Activates the configuration for a config digest
   * @param feedId Feed ID to activate config for
   * @param configDigest The config digest to activate
   * @dev This function can be called by the contract admin to activate a configuration.
   */
  function activateConfig(bytes32 feedId, bytes32 configDigest) external;

  /**
   * @notice Deactivates the configuration for a config digest
   * @param feedId Feed ID to deactivate config for
   * @param configDigest The config digest to deactivate
   * @dev This function can be called by the contract admin to deactivate an incorrect configuration.
   */
  function deactivateConfig(bytes32 feedId, bytes32 configDigest) external;

  /**
   * @notice Activates the given feed
   * @param feedId Feed ID to activated
   * @dev This function can be called by the contract admin to activate a feed
   */
  function activateFeed(bytes32 feedId) external;

  /**
   * @notice Deactivates the given feed
   * @param feedId Feed ID to deactivated
   * @dev This function can be called by the contract admin to deactivate a feed
   */
  function deactivateFeed(bytes32 feedId) external;

  /**
   * @notice returns the latest config digest and epoch for a feed
   * @param feedId Feed ID to fetch data for
   * @return scanLogs indicates whether to rely on the configDigest and epoch
   * returned or whether to scan logs for the Transmitted event instead.
   * @return configDigest
   * @return epoch
   */
  function latestConfigDigestAndEpoch(
    bytes32 feedId
  ) external view returns (bool scanLogs, bytes32 configDigest, uint32 epoch);

  /**
   * @notice information about current offchain reporting protocol configuration
   * @param feedId Feed ID to fetch data for
   * @return configCount ordinal number of current config, out of all configs applied to this contract so far
   * @return blockNumber block at which this config was set
   * @return configDigest domain-separation tag for current config
   */
  function latestConfigDetails(
    bytes32 feedId
  ) external view returns (uint32 configCount, uint32 blockNumber, bytes32 configDigest);
}

interface IVerifierFeeManager is IERC165 {
  /**
   * @notice Handles fees for a report from the subscriber and manages rewards
   * @param payload report to process the fee for
   * @param parameterPayload fee payload
   * @param subscriber address of the fee will be applied
   */
  function processFee(bytes calldata payload, bytes calldata parameterPayload, address subscriber) external payable;

  /**
   * @notice Processes the fees for each report in the payload, billing the subscriber and paying the reward manager
   * @param payloads reports to process
   * @param parameterPayload fee payload
   * @param subscriber address of the user to process fee for
   */
  function processFeeBulk(
    bytes[] calldata payloads,
    bytes calldata parameterPayload,
    address subscriber
  ) external payable;

  /**
   * @notice Sets the fee recipients according to the fee manager
   * @param configDigest digest of the configuration
   * @param rewardRecipientAndWeights the address and weights of all the recipients to receive rewards
   */
  function setFeeRecipients(
    bytes32 configDigest,
    Common.AddressAndWeight[] calldata rewardRecipientAndWeights
  ) external;
}

interface IVerifierProxy {
  /**
   * @notice Verifies that the data encoded has been signed
   * correctly by routing to the correct verifier, and bills the user if applicable.
   * @param payload The encoded data to be verified, including the signed
   * report.
   * @param parameterPayload fee metadata for billing
   * @return verifierResponse The encoded report from the verifier.
   */
  function verify(
    bytes calldata payload,
    bytes calldata parameterPayload
  ) external payable returns (bytes memory verifierResponse);

  /**
   * @notice Bulk verifies that the data encoded has been signed
   * correctly by routing to the correct verifier, and bills the user if applicable.
   * @param payloads The encoded payloads to be verified, including the signed
   * report.
   * @param parameterPayload fee metadata for billing
   * @return verifiedReports The encoded reports from the verifier.
   */
  function verifyBulk(
    bytes[] calldata payloads,
    bytes calldata parameterPayload
  ) external payable returns (bytes[] memory verifiedReports);

  /**
   * @notice Sets the verifier address initially, allowing `setVerifier` to be set by this Verifier in the future
   * @param verifierAddress The address of the verifier contract to initialize
   */
  function initializeVerifier(address verifierAddress) external;

  /**
   * @notice Sets a new verifier for a config digest
   * @param currentConfigDigest The current config digest
   * @param newConfigDigest The config digest to set
   * @param addressesAndWeights The addresses and weights of reward recipients
   * reports for a given config digest.
   */
  function setVerifier(
    bytes32 currentConfigDigest,
    bytes32 newConfigDigest,
    Common.AddressAndWeight[] memory addressesAndWeights
  ) external;

  /**
   * @notice Removes a verifier for a given config digest
   * @param configDigest The config digest of the verifier to remove
   */
  function unsetVerifier(bytes32 configDigest) external;

  /**
   * @notice Retrieves the verifier address that verifies reports
   * for a config digest.
   * @param configDigest The config digest to query for
   * @return verifierAddress The address of the verifier contract that verifies
   * reports for a given config digest.
   */
  function getVerifier(bytes32 configDigest) external view returns (address verifierAddress);

  /**
   * @notice Called by the admin to set an access controller contract
   * @param accessController The new access controller to set
   */
  function setAccessController(AccessControllerInterface accessController) external;

  /**
   * @notice Called by the admin to set an access controller contract
   * @param readAccessController The new read access controller to set
   */
  function setReadAccessController(AccessControllerInterface readAccessController) external;

  /**
   * @notice Updates the fee manager
   * @param feeManager The new fee manager
   */
  function setFeeManager(IVerifierFeeManager feeManager) external;
}

library Common {
  // @notice The asset struct to hold the address of an asset and amount
  struct Asset {
    address assetAddress;
    uint256 amount;
  }

  // @notice Struct to hold the address and its associated weight
  struct AddressAndWeight {
    address addr;
    uint64 weight;
  }

  /**
   * @notice Checks if an array of AddressAndWeight has duplicate addresses
   * @param recipients The array of AddressAndWeight to check
   * @return bool True if there are duplicates, false otherwise
   */
  function _hasDuplicateAddresses(Common.AddressAndWeight[] memory recipients) internal pure returns (bool) {
    for (uint256 i = 0; i < recipients.length; ) {
      for (uint256 j = i + 1; j < recipients.length; ) {
        if (recipients[i].addr == recipients[j].addr) {
          return true;
        }
        unchecked {
          ++j;
        }
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }
}



/**
 * The verifier proxy contract is the gateway for all report verification requests
 * on a chain.  It is responsible for taking in a verification request and routing
 * it to the correct verifier contract.
 */
contract VerifierProxy is IVerifierProxy, IPriceReader, ConfirmedOwner, TypeAndVersionInterface {
  /// @notice This event is emitted whenever a new verifier contract is set
  /// @param oldConfigDigest The config digest that was previously the latest config
  /// digest of the verifier contract at the verifier address.
  /// @param oldConfigDigest The latest config digest of the verifier contract
  /// at the verifier address.
  /// @param verifierAddress The address of the verifier contract that verifies reports for
  /// a given digest
  event VerifierSet(bytes32 oldConfigDigest, bytes32 newConfigDigest, address verifierAddress);

  /// @notice This event is emitted whenever a new verifier contract is initialized
  /// @param verifierAddress The address of the verifier contract that verifies reports
  event VerifierInitialized(address verifierAddress);

  /// @notice This event is emitted whenever a verifier is unset
  /// @param configDigest The config digest that was unset
  /// @param verifierAddress The Verifier contract address unset
  event VerifierUnset(bytes32 configDigest, address verifierAddress);

  /// @notice This event is emitted when a new access controller is set
  /// @param oldAccessController The old access controller address
  /// @param newAccessController The new access controller address
  event AccessControllerSet(address oldAccessController, address newAccessController);

  /// @notice This event is emitted when a new read access controller is set
  /// @param oldReadAccessController The old read access controller address
  /// @param newReadAccessController The new read access controller address
  event ReadAccessControllerSet(address oldReadAccessController, address newReadAccessController);

  /// @notice This event is emitted when a new fee manager is set
  /// @param oldFeeManager The old fee manager address
  /// @param newFeeManager The new fee manager address
  event FeeManagerSet(address oldFeeManager, address newFeeManager);

  /// @notice This event is emitted when a new report is verified
  event PriceFeedUpdate(bytes32 indexed id, uint32 observeAt, uint32 expiresAt, uint192 value, int8 decimal);

  /// @notice This error is thrown whenever an address tries
  /// to exeecute a transaction that it is not authorized to do so
  error AccessForbidden();

  /// @notice This error is thrown whenever an address tries
  /// to read the price that it is not authorized to do so
  error ReadAccessForbidden();

  /// @notice This error is thrown whenever a zero address is passed
  error ZeroAddress();

  /// @notice This error is thrown when trying to set a verifier address
  /// for a digest that has already been initialized
  /// @param configDigest The digest for the verifier that has
  /// already been set
  /// @param verifier The address of the verifier the digest was set for
  error ConfigDigestAlreadySet(bytes32 configDigest, address verifier);

  /// @notice This error is thrown when trying to set a verifier address that has already been initialized
  error VerifierAlreadyInitialized(address verifier);

  /// @notice This error is thrown when the verifier at an address does
  /// not conform to the verifier interface
  error VerifierInvalid();

  /// @notice This error is thrown when the fee manager at an address does
  /// not conform to the fee manager interface
  error FeeManagerInvalid();

  /// @notice This error is thrown whenever a verifier is not found
  /// @param configDigest The digest for which a verifier is not found
  error VerifierNotFound(bytes32 configDigest);

  /// @notice This error is thrown whenever billing fails.
  error BadVerification();

  /// @notice This error is thrown when the price feed not found.
  error PriceFeedNotFound();

  /// @notice This error is thrown when the price feed expires.
  error PriceFeedExpire();

  /// @notice This error is thrown when the timestamp of price feed not be tolerable.
  error StalePrice();

  /// @notice Mapping of authorized verifiers
  mapping(address => bool) private s_initializedVerifiers;

  /// @notice Mapping between config digests and verifiers
  mapping(bytes32 => address) private s_verifiersByConfig;

  /// @notice Mapping between config digests and report
  mapping(bytes32 => AproStructs.Price) internal s_report_price;

  /// @notice The contract to control addresses that are allowed to verify reports
  AccessControllerInterface public s_accessController;

  /// @notice The contract to control addresses that are allowed to read price
  AccessControllerInterface public s_readAccessController;

  /// @notice The contract to control fees for report verification
  IVerifierFeeManager public s_feeManager;

  uint256 public validTimePeriod = 120;

  constructor(AccessControllerInterface accessController) ConfirmedOwner(msg.sender) {
    s_accessController = accessController;
  }

  modifier checkAccess() {
    AccessControllerInterface ac = s_accessController;
    if (address(ac) != address(0) && !ac.hasAccess(msg.sender, msg.data)) revert AccessForbidden();
    _;
  }

  modifier checkReadAccess() {
    AccessControllerInterface rac = s_readAccessController;
    if (address(rac) != address(0) && !rac.hasAccess(msg.sender, msg.data)) revert ReadAccessForbidden();
    _;
  }

  modifier onlyInitializedVerifier() {
    if (!s_initializedVerifiers[msg.sender]) revert AccessForbidden();
    _;
  }

  modifier onlyValidVerifier(address verifierAddress) {
    if (verifierAddress == address(0)) revert ZeroAddress();
    if (!IERC165(verifierAddress).supportsInterface(IVerifier.verify.selector)) revert VerifierInvalid();
    _;
  }

  modifier onlyUnsetConfigDigest(bytes32 configDigest) {
    address configDigestVerifier = s_verifiersByConfig[configDigest];
    if (configDigestVerifier != address(0)) revert ConfigDigestAlreadySet(configDigest, configDigestVerifier);
    _;
  }

  /// @inheritdoc TypeAndVersionInterface
  function typeAndVersion() external pure override returns (string memory) {
    return "VerifierProxy 2.0.0";
  }

  /// @inheritdoc IVerifierProxy
  function verify(
    bytes calldata payload,
    bytes calldata parameterPayload
  ) external payable checkAccess returns (bytes memory) {
    IVerifierFeeManager feeManager = s_feeManager;

    // Bill the verifier
    if (address(feeManager) != address(0)) {
      feeManager.processFee{value: msg.value}(payload, parameterPayload, msg.sender);
    }

    return _verify(payload);
  }

  /// @inheritdoc IVerifierProxy
  function verifyBulk(
    bytes[] calldata payloads,
    bytes calldata parameterPayload
  ) external payable checkAccess returns (bytes[] memory verifiedReports) {
    IVerifierFeeManager feeManager = s_feeManager;

    // Bill the verifier
    if (address(feeManager) != address(0)) {
      feeManager.processFeeBulk{value: msg.value}(payloads, parameterPayload, msg.sender);
    }

    //verify the reports
    verifiedReports = new bytes[](payloads.length);
    for (uint256 i; i < payloads.length; ++i) {
      verifiedReports[i] = _verify(payloads[i]);
    }

    return verifiedReports;
  }

  function _verify(bytes calldata payload) internal returns (bytes memory verifiedReport) {
    // First 32 bytes of the signed report is the config digest
    bytes32 configDigest = bytes32(payload);
    address verifierAddress = s_verifiersByConfig[configDigest];
    if (verifierAddress == address(0)) revert VerifierNotFound(configDigest);

    return IVerifier(verifierAddress).verify(payload, msg.sender);
  }

  /// @inheritdoc IVerifierProxy
  function initializeVerifier(address verifierAddress) external override onlyOwner onlyValidVerifier(verifierAddress) {
    if (s_initializedVerifiers[verifierAddress]) revert VerifierAlreadyInitialized(verifierAddress);

    s_initializedVerifiers[verifierAddress] = true;
    emit VerifierInitialized(verifierAddress);
  }

  /// @inheritdoc IVerifierProxy
  function setVerifier(
    bytes32 currentConfigDigest,
    bytes32 newConfigDigest,
    Common.AddressAndWeight[] calldata addressesAndWeights
  ) external override onlyUnsetConfigDigest(newConfigDigest) onlyInitializedVerifier {
    s_verifiersByConfig[newConfigDigest] = msg.sender;

    // Empty recipients array will be ignored and must be set off chain
    if (addressesAndWeights.length > 0) {
      if (address(s_feeManager) == address(0)) {
        revert ZeroAddress();
      }

      s_feeManager.setFeeRecipients(newConfigDigest, addressesAndWeights);
    }

    emit VerifierSet(currentConfigDigest, newConfigDigest, msg.sender);
  }

  /// @inheritdoc IVerifierProxy
  function unsetVerifier(bytes32 configDigest) external override onlyOwner {
    address verifierAddress = s_verifiersByConfig[configDigest];
    if (verifierAddress == address(0)) revert VerifierNotFound(configDigest);
    delete s_verifiersByConfig[configDigest];
    emit VerifierUnset(configDigest, verifierAddress);
  }

  /// @inheritdoc IVerifierProxy
  function getVerifier(bytes32 configDigest) external view override returns (address) {
    return s_verifiersByConfig[configDigest];
  }

  /// @inheritdoc IVerifierProxy
  function setAccessController(AccessControllerInterface accessController) external onlyOwner {
    address oldAccessController = address(s_accessController);
    s_accessController = accessController;
    emit AccessControllerSet(oldAccessController, address(accessController));
  }

  /// @inheritdoc IVerifierProxy
  function setReadAccessController(AccessControllerInterface readAccessController) external onlyOwner {
    address oldReadAccessController = address(s_readAccessController);
    s_readAccessController = readAccessController;
    emit ReadAccessControllerSet(oldReadAccessController, address(readAccessController));
  }

  /// @inheritdoc IVerifierProxy
  function setFeeManager(IVerifierFeeManager feeManager) external onlyOwner {
    if (address(feeManager) == address(0)) revert ZeroAddress();

    if (
      !IERC165(feeManager).supportsInterface(IVerifierFeeManager.processFee.selector) ||
      !IERC165(feeManager).supportsInterface(IVerifierFeeManager.processFeeBulk.selector)
    ) revert FeeManagerInvalid();

    address oldFeeManager = address(s_feeManager);
    s_feeManager = IVerifierFeeManager(feeManager);
    emit FeeManagerSet(oldFeeManager, address(feeManager));
  }

  /// @inheritdoc IPriceReader
  function updateReport(bytes calldata report) external onlyInitializedVerifier {
    (bytes32 feedId, , uint32 observeAt, , , uint32 expiresAt, uint192 value) = abi.decode(
      report,
      (bytes32, uint32, uint32, uint192, uint192, uint32, uint192)
    );
    AproStructs.Price storage price = s_report_price[feedId];
    if (observeAt > price.observeAt) {
      price.value = value;
      price.decimal = 18;
      price.observeAt = observeAt;
      price.expireAt = expiresAt;
      emit PriceFeedUpdate(feedId, observeAt, expiresAt, value, 18);
    }
  }

  function setValidTimePeriod(uint256 _validTimePeriod) external onlyOwner {
    validTimePeriod = _validTimePeriod;
  }

  function getValidTimePeriod() public view override returns (uint256) {
    return validTimePeriod;
  }

  /// @inheritdoc IPriceReader
  function getPrice(
    bytes32 id
  ) external view checkReadAccess returns (AproStructs.Price memory price){
    return getPriceNoOlderThan(id, getValidTimePeriod());
  }

  /// @inheritdoc IPriceReader
  function getPriceUnsafe(
      bytes32 id
  ) public view  checkReadAccess returns (AproStructs.Price memory price){
    price = s_report_price[id];

    if (price.observeAt == 0) revert PriceFeedNotFound();

    if (price.expireAt < block.timestamp) revert PriceFeedExpire();

    return price;
  }

  /// @inheritdoc IPriceReader
  function getPriceNoOlderThan(
      bytes32 id,
      uint age
  ) public view  checkReadAccess returns (AproStructs.Price memory price){
    price = getPriceUnsafe(id);

    if (block.timestamp > price.observeAt && block.timestamp - price.observeAt > age) revert StalePrice();

    return price;
  }

}