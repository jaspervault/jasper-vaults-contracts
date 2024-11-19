// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
interface IVaultMetaFacet {

    struct MetaData {
       string name;
    }

    event SetVaultMetaData(address _vault, MetaData _data);

    function getVaultMetaData(address _vault) external view returns(MetaData memory metaData);
    function setVaultMetaData(address _vault, MetaData memory _data) external;
}
