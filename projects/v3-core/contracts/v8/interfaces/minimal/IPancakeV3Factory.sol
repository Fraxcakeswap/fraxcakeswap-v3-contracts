// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title The interface for the PancakeSwap V3 Factory
/// @notice The PancakeSwap V3 Factory facilitates creation of PancakeSwap V3 pools and control over the protocol fees
interface IPancakeV3Factory {
    /// @notice Returns the current owner of the factory
    /// @dev Can be changed by the current owner via setOwner
    /// @return The address of the factory owner
    function owner() external view returns (address);

    function getSwapFee(address sender, uint24 fee) external returns(uint24);
}
