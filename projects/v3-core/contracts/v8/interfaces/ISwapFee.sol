// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ISwapFee
{
    function swapFee(address sender, uint24 fee) external view returns(uint24);
}