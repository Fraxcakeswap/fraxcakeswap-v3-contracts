// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import './interfaces/IERC20Minimal.sol';
import './interfaces/ISwapFee.sol';

contract SwapFee is ISwapFee {
    address public owner;
    address public fraxPoints;

    uint256 public tier1;
    uint256 public tier2;
    uint256 public tier3;
    uint16 public tier1Percentage;
    uint16 public tier2Percentage;
    uint16 public tier3Percentage;
    uint16 public getMaxTierPercentage;
    uint16 public constant TIER_PERCENTAGE_MAX = 10000;

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    error NotOwner();
    error InvalidPercentages();

    modifier onlyOwner() {
        if(msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(
        address _fraxPoints,
        uint256 _tier1,
        uint256 _tier2,
        uint256 _tier3,
        uint16 _tier1Percentage,
        uint16 _tier2Percentage,
        uint16 _tier3Percentage   
    ) {
        if(
            _tier1Percentage >= TIER_PERCENTAGE_MAX
            || _tier2Percentage >= TIER_PERCENTAGE_MAX
            || _tier3Percentage >= TIER_PERCENTAGE_MAX
        ) revert InvalidPercentages();

        tier1 = _tier1;
        tier2 = _tier2;
        tier3 = _tier3;
        tier1Percentage = _tier1Percentage;
        tier2Percentage = _tier2Percentage;
        tier3Percentage = _tier3Percentage;
        owner = msg.sender;
        fraxPoints = _fraxPoints;
    }

    function setFraxPoints(address _fraxPoints) external onlyOwner {
        fraxPoints = _fraxPoints;
    }

    function setOwner(address _owner) external onlyOwner {
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function setFraxTiers(
        uint256 _tier1,
        uint256 _tier2,
        uint256 _tier3,
        uint16 _tier1Percentage,
        uint16 _tier2Percentage,
        uint16 _tier3Percentage
    ) external onlyOwner {
        if(
            _tier1Percentage >= TIER_PERCENTAGE_MAX
            || _tier2Percentage >= TIER_PERCENTAGE_MAX
            || _tier3Percentage >= TIER_PERCENTAGE_MAX
        ) revert InvalidPercentages();

        tier1 = _tier1;
        tier2 = _tier2;
        tier3 = _tier3;
        tier1Percentage = _tier1Percentage;
        tier2Percentage = _tier2Percentage;
        tier3Percentage = _tier3Percentage;
    }

    function swapFee(address sender, uint24 fee) external view returns(uint24) {
        uint24 _fee = fee;
        if (fraxPoints != address(0)) {
            uint256 balance = IERC20Minimal(fraxPoints).balanceOf(sender);
            uint256 totalSupply = IERC20Minimal(fraxPoints).totalSupply();

            if (totalSupply/tier1 <= balance) {
                _fee = uint24((uint256(fee) * (TIER_PERCENTAGE_MAX - tier1Percentage)) / TIER_PERCENTAGE_MAX);
            } else if (totalSupply/tier2 <= balance) {
                _fee = uint24((uint256(fee) * (TIER_PERCENTAGE_MAX - tier2Percentage)) / TIER_PERCENTAGE_MAX);
            } else if (totalSupply/tier3 <= balance) {
                _fee = uint24((uint256(fee) * (TIER_PERCENTAGE_MAX - tier3Percentage)) / TIER_PERCENTAGE_MAX);
            }
        }

        return _fee;
    }
}