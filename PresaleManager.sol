// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Safe ERC20 and BEP20 Token Presale Manager
/// @author Jorge López Pellicer
/// @dev https://www.linkedin.com/in/jorge-lopez-pellicer/

import "./interface/IPresaleManager.sol";
import "./SafeTokenPresale.sol";
contract PresaleManager is IPresaleManager {

    address public uniswapRouter;
    address[] public presales;
    mapping(address => address[]) public presalers;

    event PresaleCreated(address indexed presaleAddress, address indexed tokenAddress, uint256 goal);

    /// @notice Constructor of PresaleManager
    /// @param _uniswapRouter: Address of Uniswap Router to be used
    constructor(address _uniswapRouter) {
        uniswapRouter = _uniswapRouter;
    }

    /// @notice This function creates a safe presale for a given token address and a given ETH goal
    /// @param _token: This is the token address the presale is created for
    /// @param _goal: The ETH goal to reach for this presale to be completed
    /// Conditions:
    ///     - Token must be a valid address
    ///     - Goal must be over 0
    /// Events:
    ///     - Once a presale is created the event PresaleCreated is emitted
    /// @return The address of the created presale is returned 
    function createPresale(address _token, uint256 _goal) external override returns (address) {
        require(_token != address(0), "Invalid token address");
        require(_goal > 0, "Goal must be greater than 0");

        SafeTokenPresale newPresale = new SafeTokenPresale(_token, _goal, uniswapRouter);
        presales.push(address(newPresale));
        presalers[msg.sender].push(address(newPresale));
        emit PresaleCreated(address(newPresale), _token, _goal);
        return address(newPresale);
    }

    /// @notice This function returns the list of presales created
    function getPresales() external view override returns (address[] memory) {
        return presales;
    }

    /// @notice This function returns the list of presales based on an address
    function getPresalesForCreator(address creator) external view override returns (address[] memory) {
        return presalers[creator];
    }
}
