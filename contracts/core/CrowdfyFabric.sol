//SPDX-License-Identifier:  MIT
pragma solidity 0.8.15;

import "./Crowdfy.sol";
import "../interfaces/CrowdfyFabricI.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**@title Factory contract for the creation of Crowdfy campaigns
 * @author Kevin Bravo (@_bravoK)
 * @dev Implements the minimal proxy pattern from openzeppelin
 *
 * This contract keeps track of all the campaigns created in the Protocol and also manage what are the tokens that a campaign can accept
 *
 * The contract is designed to be owned by a Governor contract, which is the responable for whitelist new tokens and also to change the core Crowdfy contract.
 */
contract CrowdfyFabric is CrowdfyFabricI {
    using SafeERC20 for IERC20;
    //** **************** STRUCTS ********************** */
    /**
     * @notice uses to stores the general information of a campaign
     * @param campaignName the name of the campaign
     * @param fundingGoal the minimum amount that the campagin requires to be succesfull
     * @param fundingCap the maximum amount that the campaign require to be closed
     * @param deadline the deadline in which the campaign would close
     * @param beneficiary the address who will receive the founds collected in case of successs
     * @param owner the creator of the campaign
     * @param created the block time when the campaign was created
     * @param campaignAddress the address of this clonce campaign
     * @param selecttedToken // the token in which the beneficiary of the campaign would receive founds / set address(0) for receive eth
     */
    struct Campaign {
        string campaignName;
        uint256 fundingGoal;
        uint256 fundingCap;
        uint256 deadline;
        address beneficiary;
        address owner;
        uint256 created;
        address campaignAddress;
        address selectedToken;
    }

    //** **************** STATE VARIABLES ********************** */

    ///@notice Stores all campaign structures
    Campaign[] public campaigns;

    ///@notice points each campaigns adddress to an identifier.
    mapping(uint256 => address) public campaignsById;

    ///@notice the address of the base campaign contract implementation
    address payable campaignImplementation;

    ///@notice the address of the protocol Owner
    address public protocolOwner;

    ///@notice the address of the Token used in the protocol
    address public crowdfyTokenAddress;

    ///@notice list of tokens that a user could select to found the campaign with
    address[] public whitelistedTokensArr;

    ///@notice allow us to know what token is whitelisted
    mapping(address => bool) public isWhitelisted;

    ///@notice points each whitelisted token adddress to an identifier.
    mapping(address => uint256) public whitelistedTokensId;
    uint256 immutable allowToIssuePerCampaign;

    //** **************** EVENTS ********************** */
    ///@notice emits whenever a new campaign is created
    event CampaignCreated(
        string indexed campaignName,
        address indexed creator,
        address beneficiary,
        uint256 fundingGoal,
        uint256 createdTime,
        uint256 deadline,
        address selectedToken,
        address indexed campaignAddress
    );
    ///@notice emits when update whitelisted Tokens
    event WhitlistedTokensUpdated(address[] _newWithlistedTokens);
    event WhitelistedTokenRemoved(address[] _tokenRemoved);
    event ImplemenationContractChange(address indexed);
    event protocolOwnerChanged(address indexed _newOwner);

/// CrowdfyFabric: The token `_token` is not whitelisted
///@param _token the token that the user set as input
error IsNotWhitelisted(address _token);
///CrowdfyFabric: Only the Owner of the protocol can call this function.
/// Require `_owner` but given `_caller`
error Unauthorized(address _caller, address _owner);
/// CrowdfyFabric: The token `_token` is already whitelisted.
///@param _token the token that the user set as input
error AlreadyInTheList(address _token);

error IsAddress0();
    //** **************** CONSTRUCTOR ********************** */

    modifier onlyOwner() {
        if(msg.sender != protocolOwner) revert Unauthorized(msg.sender, protocolOwner);
        _;
    }

    constructor(
        address[] memory _whitelistedTokens,
        address _crwodfyTokenAddr,
        uint256 _allowancePerCampaign
    ) {
        protocolOwner = msg.sender;
        emit protocolOwnerChanged(msg.sender);
        //deploys the campaign base implementation
        campaignImplementation = payable(address(new Crowdfy()));
        emit ImplemenationContractChange(campaignImplementation);
        setWhitelistedTokens(_whitelistedTokens);
        crowdfyTokenAddress = _crwodfyTokenAddr;
        allowToIssuePerCampaign = _allowancePerCampaign;
    }

    /**
     * @notice Deploy a new instance of the campaign
     **/
    function createCampaign(
        string calldata _campaignName,
        uint256 _fundingGoal,
        uint256 _deadline,
        uint256 _fundingCap,
        address _beneficiaryAddress,
        address _selectedToken
    ) external returns (uint256) {
        if(!isWhitelisted[_selectedToken]) revert IsNotWhitelisted(_selectedToken);
        //Do not allow to burn the founds collected.
        if(_beneficiaryAddress == address(0)) revert IsAddress0();
        address campaignCreator = msg.sender;

        address payable cloneContract = payable(
            Clones.clone(campaignImplementation)
        );
        //allows the created contract to send tokens to the owner
        IERC20(crowdfyTokenAddress).safeApprove(
            address(cloneContract),
            allowToIssuePerCampaign
        );

        Crowdfy(cloneContract).initializeCampaign(
            _campaignName,
            _fundingGoal,
            _deadline,
            _fundingCap,
            _beneficiaryAddress,
            campaignCreator,
            address(this),
            _selectedToken // if you want to receive your founds in eth you pass address(0)
        );

        campaigns.push(
            Campaign({
                campaignName: _campaignName,
                fundingGoal: _fundingGoal,
                fundingCap: _fundingCap,
                deadline: _deadline,
                beneficiary: _beneficiaryAddress,
                owner: campaignCreator,
                created: block.timestamp,
                campaignAddress: address(cloneContract),
                selectedToken: _selectedToken
            })
        );

        uint256 campaignId = campaigns.length - 1;
        campaignsById[campaignId] = cloneContract;

        emit CampaignCreated(
            _campaignName,
            campaignCreator,
            _beneficiaryAddress,
            _fundingCap,
            block.timestamp,
            _deadline,
            _selectedToken,
            cloneContract
        );

        return campaignId;
    }

    ///@notice gets the total number number of campaigns created
    function getCampaignsLength() external view returns (uint256) {
        return campaigns.length;
    }

    ///@notice gets the total count of whitelistedTokens
    function getTotalTokens() external view returns (uint256) {
        return whitelistedTokensArr.length;
    }

    /**@notice Whitelist a bunch of tokens to be used in the protocol
     * @dev this function runs in linear time O(n)
     **/
    function setWhitelistedTokens(address[] memory _tokens) public onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            // uint256 tokenId = whitelistedTokensId[_tokens[i]];
            // if(!isWhitelisted[_tokens[i]] && whitelistedTokensArr[tokenId] != address(0)) AlreadyInTheList(_tokens[i]);
            whitelistedTokensArr.push(_tokens[i]);
            isWhitelisted[_tokens[i]] = true;
            whitelistedTokensId[_tokens[i]] = whitelistedTokensArr.length - 1;
        }
        emit WhitlistedTokensUpdated(_tokens);
    }

    /**@notice removes tokens from the whitelist.
     * @dev This function Just sets the {isWhitelisted} of the token given to false. Being more cheaper that looking for the address of the token in the arr and delete it.
     *
     * And also allow us to rewhitelist the token again in a very efficient way.
     * This function runs in linear time O(n)
     **/
    function quitWhitelistedToken(address[] memory _tokens) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 tokenId = whitelistedTokensId[_tokens[i]];
            if(isWhitelisted[_tokens[i]] && whitelistedTokensArr[tokenId] != address(0)) revert IsNotWhitelisted(_tokens[i]);
            isWhitelisted[_tokens[i]] = false;
        }
        emit WhitelistedTokenRemoved(_tokens);
    }

    /**@notice Allow to whitelist a token again, if the token were baned
     * @dev this function should be called only if the token you want to whitelist is already in the {whitelistedTokensArr} and was removed by the `quitWhitelistedToken` function
     *
     * Just sets the {isWhitelisted} of the token given to true. Being more cheaper that store the address of the token again in the arr
     * This functions runs in linear time O(n)
     **/
    function reWhitelistToken(address[] memory _tokens) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 tokenId = whitelistedTokensId[_tokens[i]];
            if(!isWhitelisted[_tokens[i]] && whitelistedTokensArr[tokenId] != address(0)) revert AlreadyInTheList(_tokens[i]);
            isWhitelisted[_tokens[i]] = true;
        }
        emit WhitlistedTokensUpdated(_tokens);
    }

    /**@notice allow to change the address of the campaign implementation.
     * @dev Can only be called by the actual owner of the current contract
     * Emmits {ImplemenationContractChange} event
     **/
    function changeCrowdfyCampaignImplementation(
        address _newImplementationAddress
    ) external onlyOwner {
        campaignImplementation = payable(_newImplementationAddress);
        emit ImplemenationContractChange(_newImplementationAddress);
    }

    /**
     * @notice allows to change the campaign owner.
     * @dev Can only be called by the actual owner of the contract.
     * Emits {protocolOwnerChanged} event
     * */
    function changeProtocolOwner(address _newOwner) public onlyOwner {
        protocolOwner = _newOwner;
        emit protocolOwnerChanged(_newOwner);
    }
}
