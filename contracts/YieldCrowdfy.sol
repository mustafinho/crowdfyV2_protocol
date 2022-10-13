// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/external/IPool.AVEE.sol";
import "./interfaces/external/IPoolAddressesProvider.AVEE.sol";
import "./interfaces/external/IAToken.AAVE.sol";

contract YieldCrowdfy {
    using SafeERC20 for IERC20;

    event yieldFarmingStarted(address _assetAddress, uint256 _amountDeposited, address _campaignAddress);
    event yieldFarmingFinished(address _assetAddress, address campaignAddress, uint256 _interestEarned);

    address public constant POOL_ADDRESSES_PROVIDER_ADDRESS = 0xc4dCB5126a3AfEd129BC3668Ea19285A9f56D15D;
    address public constant ATOKEN_ADDRESS = 0xF2EBFA003f04f38Fc606a37ab8D1c015c015725c;
    bool public isYielding;

    function deposit(
        address _assetAddress, 
        uint256 _amount, 
        address _campaignAddress
    ) internal returns (bool) {
        address lendingPool = getAAVELendingPool();
        IERC20(_assetAddress).safeApprove(lendingPool, _amount);
        IPool(lendingPool).supply(_assetAddress, _amount,  _campaignAddress ,0);
        emit yieldFarmingStarted(_assetAddress, _amount, _campaignAddress);
        isYielding = true;
        return true;
    }

    function withdrawYield(address _assetAddress, address _campaignAddress) internal returns(uint256) {
        require(isYielding, "YieldFarming: you cannot withdraw if you are not yielding");
        address lendingPool = getAAVELendingPool();
        uint256 interestEarned = IPool(lendingPool).withdraw(_assetAddress, type(uint256).max, _campaignAddress);
        emit yieldFarmingFinished(_assetAddress, _campaignAddress, interestEarned);
        isYielding = false;
        return interestEarned;
    }

    function getAAVELendingPool() internal view returns(address lendingPool){
        lendingPool = IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER_ADDRESS).getPool();
    }

    function getBalanceWithInterest(
        address _campaignAddress
    ) external view returns(uint256) {
        return IAToken(ATOKEN_ADDRESS).balanceOf(_campaignAddress);
    }

    function getBalanceWithoutInterest(
        address _campaignAddress      
    ) external view returns(uint256) {
        return IAToken(ATOKEN_ADDRESS).principalBalanceOf(_campaignAddress);
    }
}