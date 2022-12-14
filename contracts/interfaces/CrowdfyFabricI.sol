//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface CrowdfyFabricI {
    /**@notice this function creates an instance of the crowdfy contract and then stores that instance in an array. Also stores the address of the camppaign created
in a mapping pointing with an id
    @param _campaignName the name of the campaign
    @param _fundingGoal the miinimum amount to make the campaign success
    @param _fundingCap the maximum amount to collect, when reached the campaign closes
    @param _beneficiaryAddress the address ot the beneficiary of the campaign
    @param _selectedToken the token in wich the beneficiary would receive the founds. 

    @dev this function follows the minimal proxi pattern to creates the instances of the crowdfy contract in a very gas efficient way. 
    @custom:see 
*/
    function createCampaign(
        string calldata _campaignName,
        uint256 _fundingGoal,
        uint256 _deadline,
        uint256 _fundingCap,
        address _beneficiaryAddress,
        address _selectedToken
    ) external returns (uint256);

    function protocolOwner() external view returns (address);

    function crowdfyTokenAddress() external view returns (address);
    // function setWhitelistedTokens(address[] memory _tokens) external;
    // function reWhitelistToken(address[] memory _tokens) external;
}
