// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacetV2} from "./IOptionFacetV2.sol";
import {IOptionFacet} from "./IOptionFacet.sol";
import {IOptionService} from "./IOptionService.sol";
import {IOptionModuleV2} from "./IOptionModuleV2.sol";
interface IOptionModuleV2Handle {
    function handlePremiumSign(
        IOptionModuleV2.PremiumOracleSign memory _sign
    ) external view ;

    function verifyManagedOrder(IOptionModuleV2.ManagedOrder memory _info, IOptionFacetV2.ManagedOptionsSettings memory _setting) external view;
}
