// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Safe ERC20 and BEP20 Token Presale
/// @author Jorge López Pellicer
/// @dev https://www.linkedin.com/in/jorge-lopez-pellicer/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract SafeTokenPresale {

    address public token;
    address public owner;
    address public uniswapRouter;
    uint256 public goal;
    uint256 public totalRaised;
    bool public enabled = false;

    mapping(address => uint256) public investments;
    mapping(address => uint256) public rewards;

    event Invested(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 tokens);
    event Exit(address indexed user, uint256 amount);
    event TokensDeposited(address indexed user, uint256 amount);
    event InvestingEnabled(bool enabled);
    event GoalReached(address);
    event InvestingCompleted();
    event GoalStablished(uint256);

    /// @notice Modifier for checking sender
    modifier onlyPresaleOwner() {
        require(msg.sender == owner, "Not the owner!");
        _;
    }

    /// @notice Constructor of SafeeTokenPresale
    /// @param _token: Address of token this presale is being created for
    /// @param _goal: Amount of ETH to reach for sharing the tokens among investors
    /// Events:
    ///     - After setting goal the event GoalStablished is emitted
    constructor(address _token, uint256 _goal, address _uniswapRouter) {
        token = _token;
        uniswapRouter = _uniswapRouter;
        goal = _goal;
        owner = msg.sender;
        emit GoalStablished(_goal);
    }

    /// @notice Payable function to exchange ETH for the pledge of an amount of tokens
    /// It will increase the reserve of tokens for the payer proportionally, based on the following formula: presale_tokens_amount * ETH_input / ETH_goal;
    /// Conditions: 
    ///     - Sent ETH amount is above 0
    ///     - Goal of this presale has not been reached yet
    /// Important:
    ///     - If you send more ETH than needed for reaching the goal, only the needed ETH will be charged
    /// Events:
    ///     - When a new payment is realized Invested event is emitted
    ///     - If the payment reached the goal GoalReached event is emitted
    function invest() external payable {
        require(enabled, "Investing must be enabled");
        require(msg.value > 0, "You must send ETH to invest");
        require(totalRaised < goal, "Required invested has already been reached");

        uint256 missingInvesting = goal - totalRaised;
        uint256 acceptedInvestment = missingInvesting > msg.value ? msg.value : missingInvesting;
        IERC20 iToken = IERC20(token);
        uint256 userReward = (iToken.balanceOf(address(this)) * acceptedInvestment) / goal;

        investments[msg.sender] += acceptedInvestment;
        rewards[msg.sender] += userReward;
        totalRaised += acceptedInvestment;
        
        emit Invested(msg.sender, acceptedInvestment);

        if(totalRaised == goal) { 
            emit GoalReached(address(token));
        }
    }

    /// @notice Anyone can anytime exit this presale and recover the ETH sent to this contract
    /// The ETH of the requester will be sent to the wallet address
    /// Conditions:
    ///     - There must be ETH previously payed by the user
    /// Events:
    ///     - When any account exits the presale the Exit event will be emitted
    function exitInvesting() external {
        uint256 userInvestment = investments[msg.sender];
        require(userInvestment > 0, "No investment found for user");
        payable(msg.sender).transfer(userInvestment);
        investments[msg.sender] = 0;
        rewards[msg.sender] = 0;
        totalRaised -= userInvestment;
        emit Exit(msg.sender, userInvestment);
    }

    /// @notice This method allows the user to receive the user's amount of tokens reserve
    /// Conditions:
    ///     - ETH Goal must have been reached
    ///     - There must be ETH previously payed by the user
    ///     - There must be pending rewards for the user
    /// Events:
    ///     - When any account asks for the account's token reserve the event Withdrawn will be emitted
    function withdraw() external {
        require(totalRaised >= goal, "Withdrawn is allowed once goal is reached");

        uint256 userInvestment = investments[msg.sender];
        uint256 userRewards = rewards[msg.sender];

        require(userInvestment > 0, "No investment found for user");
        require(userRewards > 0, "No rewards found for user");

        IERC20 iToken = IERC20(token);
        require(iToken.transfer(msg.sender, userRewards), "Token transfer failed");
        
        rewards[msg.sender] = 0;
        investments[msg.sender] = 0;
        emit Withdrawn(msg.sender, userInvestment, userRewards);
    }

    /// @notice Read function for checking the current preseale status
    /// Raised ETH and Goal ETH values are returned
    function getPresaleStatus() external view returns (uint256, uint256) {
        return (totalRaised, goal);
    }

    /// @notice Read function for checcking the account pending rewards
    function getMyRewards() external view returns(uint256) {
        return rewards[msg.sender];
    }

    /// @notice This function allows the presale owner to receive the ETH payed by investors 
    /// Right after this function is completed the presale is considered as disabled so anyone else can pay more ETH
    /// Conditions:
    ///     - Only owner can use this function
    ///     - Goal must have been reached
    /// Events:
    ///     - When owner requests ETH the event InvestingCompleted is emitted
    function withdrawRemainingETH() external onlyPresaleOwner { //To be deprecated
        require(totalRaised >= goal, "Goal not reached yet");
        payable(owner).transfer(address(this).balance);
        enabled = false;
        emit InvestingCompleted();
    }

    /// @notice This function allows the creates the pair for trading using ETH sent by investors 
    /// Right after this function is completed the presale is considered as disabled so anyone else can pay more ETH
    /// Conditions:
    ///     - Anyone can execute this function
    ///     - Goal must have been reached
    /// Events:
    ///     - When completed the event InvestingCompleted is emitted
    function createPair() external payable {
        require(totalRaised >= goal, "Goal not reached yet");
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(uniswapRouter);

        IERC20 iToken = IERC20(token);
        ERC20 eToken = ERC20(token);

        iToken.approve(address(this), eToken.balanceOf(address(this)));
        address uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(token,uniswapV2Router.WETH());

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            token,
            eToken.balanceOf(address(this)),
            0,
            0,
            address(0),
            block.timestamp
        );
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint256).max);

        enabled = false;
        emit InvestingCompleted();
    }

    /// @notice This function allows the owner to set the ETH goal for this presale
    /// @param newGoal: This is the ETH amount to reach for this presale to be completed
    /// Conditions:
    ///     - newGoal must be above 0
    ///     - Sender must be the owner
    ///     - Investing must be disabled (this prevents owner to modify presale configuration after enabling it)
    /// Events:
    ///     - After setting goal the event GoalStablished is emitted
    function setGoal(uint256 newGoal) external onlyPresaleOwner {
        require(newGoal > 0, "Goal cannot be so low");
        require(enabled == false, "Investing has already started");
        goal = newGoal;
        emit GoalStablished(newGoal);
    }

    /// @notice This function allows anyone to get the presale's token details
    function getTokenAddress() external view returns (address tokenAddress) {
        return token;
    }

    /// @notice This function allows anyone to get uniswap router address
    function getUniswapRouterAddress() external view returns (address routerAddress) {
        return uniswapRouter;
    }

    /// @notice This function allows anyone to get the presale's token details
    function getTokenDetails() external view returns (address tokenAddress, string memory symbol, string memory name, uint8 decimals, uint256 balance) {
        ERC20 eToken = ERC20(token);
        symbol = eToken.symbol();
        name = eToken.name();
        decimals = eToken.decimals();
        balance = eToken.balanceOf(address(this));
        return (token, symbol, name, decimals, balance);
    }

    /// @notice This method allows the owner to deposit the tokens this presale is created for
    /// Conditions:
    ///     - Sender must be the owner
    ///     - Investing must be disabled (this prevents owner to modify presale configuration after enabling it)
    ///     - Amount of tokens must be above 0
    ///     - Tokens must be sent to this smart contract
    /// Events:
    ///     - When tokens are sent to this contract event TokensDeposited is emitted
    function depositTokens(uint256 amount) external onlyPresaleOwner {
        require(enabled == false, "Investing has already started");
        require(amount > 0, "Amount must be greater than 0");
        require(address(token) != address(0), "Not valid address");
        IERC20 iToken = IERC20(token);
        require(iToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        emit TokensDeposited(msg.sender, amount);
    }

    /// @notice This function allows anyone to send ETH and participate on the presale
    /// Conditions:
    ///     - Only owner can enable investing
    ///     - Investing cannot be already open
    /// Events:
    ///     - Once participation is allowed event InvestingEnabled is emitted
    function enableInvesting() external onlyPresaleOwner {
        require(enabled == false, "Investing is already open");
        enabled = true;
        emit InvestingEnabled(enabled);
    }    
}
