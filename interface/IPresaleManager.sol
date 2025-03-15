// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Safe ERC20 and BEP20 Token Presale
/// @author Jorge López Pellicer
/// @dev https://www.linkedin.com/in/jorge-lopez-pellicer/

interface IPresaleManager {
    function createPresale(address token, uint256 goal) external returns (address);
    function getPresales() external view returns (address[] memory);
    function getPresalesForCreator(address creator) external view returns (address[] memory);
}
