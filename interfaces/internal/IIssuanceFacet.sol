// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;


interface IIssuanceFacet{
    enum IssueMode{
        Default,
        Normal,
        Proxy
    }
    event SetIssueMode(address _vault,IssueMode _mode);
    event SetIssuer(address _vault,address _issuer);
    event SetProxyIssueWhiteList(address _vault,address _issuer,bool _status);
    function getIssueMode(address _vault) external view returns(IssueMode);
    function setIssueMode(address _vault,IssueMode _mode) external; 
    function getIssuer(address _vault) external view returns(address);
    function setIssuer(address _vault,address _issuer) external;
    function setProxyIssueWhiteList(address _vault,address _issuer,bool _status) external;
    function getProxyIssueWhiteList(address _vault,address _issuer) external view returns(bool);
}

