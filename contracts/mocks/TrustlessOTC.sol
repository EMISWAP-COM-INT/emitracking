//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TrustlessOTC is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public balanceTracker;
    mapping(address => uint256) public feeTracker;
    mapping(address => uint256[]) public tradeTracker;

    event OfferCreated(uint256 indexed tradeID);
    event OfferCancelled(uint256 indexed tradeID);
    event OfferTaken(uint256 indexed tradeID);

    uint256 public feeBasisPoints;

    constructor(uint256 _feeBasisPoints) {
        feeBasisPoints = _feeBasisPoints;
    }

    struct TradeOffer {
        address tokenFrom;
        address tokenTo;
        uint256 amountFrom;
        uint256 amountTo;
        address payable creator;
        address optionalTaker;
        bool active;
        bool completed;
        uint256 tradeID;
    }

    TradeOffer[] public offers;

    function initiateTrade(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountFrom,
        uint256 _amountTo,
        address _optionalTaker
    ) public payable returns (uint256 newTradeID) {
        if (_tokenFrom == address(0)) {
            require(msg.value == _amountFrom);
        } else {
            require(msg.value == 0);
            IERC20(_tokenFrom).safeTransferFrom(
                msg.sender,
                address(this),
                _amountFrom
            );
        }
        balanceTracker[_tokenFrom] = balanceTracker[_tokenFrom] + _amountFrom;

        //offers.length++;
        newTradeID = offers.length + 1;
        TradeOffer memory o;
        o.tokenFrom = _tokenFrom;
        o.tokenTo = _tokenTo;
        o.amountFrom = _amountFrom;
        o.amountTo = _amountTo;
        o.creator = payable(msg.sender);
        o.optionalTaker = _optionalTaker;
        o.active = true;
        o.tradeID = newTradeID;

        offers.push(o);

        tradeTracker[msg.sender].push(newTradeID);
        emit OfferCreated(newTradeID);
    }

    function cancelTrade(uint256 tradeID) public returns (bool) {
        TradeOffer storage o = offers[tradeID];
        require(msg.sender == o.creator);
        require(o.active == true);
        o.active = false;
        if (o.tokenFrom == address(0)) {
            payable(msg.sender).transfer(o.amountFrom);
        } else {
            IERC20(o.tokenFrom).safeTransfer(o.creator, o.amountFrom);
        }
        balanceTracker[o.tokenFrom] -= o.amountFrom;
        emit OfferCancelled(tradeID);
        return true;
    }

    function take(uint256 tradeID) public payable returns (bool) {
        TradeOffer storage o = offers[tradeID];
        require(o.optionalTaker == msg.sender || o.optionalTaker == address(0));
        require(o.active == true);
        o.active = false;
        balanceTracker[o.tokenFrom] -= o.amountFrom;
        uint256 fee = (o.amountFrom * feeBasisPoints) / 10000;
        feeTracker[o.tokenFrom] += fee;
        tradeTracker[msg.sender].push(tradeID);

        if (o.tokenFrom == address(0)) {
            payable(msg.sender).transfer(o.amountFrom - fee);
        } else {
            IERC20(o.tokenFrom).safeTransfer(msg.sender, o.amountFrom - fee);
        }

        if (o.tokenTo == address(0)) {
            require(msg.value == o.amountTo);
            o.creator.transfer(msg.value);
        } else {
            require(msg.value == 0);
            IERC20(o.tokenTo).safeTransferFrom(
                msg.sender,
                o.creator,
                o.amountTo
            );
        }
        o.completed = true;
        emit OfferTaken(tradeID);
        return true;
    }

    function getOfferDetails(uint256 tradeID)
        external
        view
        returns (
            address _tokenFrom,
            address _tokenTo,
            uint256 _amountFrom,
            uint256 _amountTo,
            address _creator,
            uint256 _fee,
            bool _active,
            bool _completed
        )
    {
        TradeOffer storage o = offers[tradeID];
        _tokenFrom = o.tokenFrom;
        _tokenTo = o.tokenTo;
        _amountFrom = o.amountFrom;
        _amountTo = o.amountTo;
        _creator = o.creator;
        _fee = (o.amountFrom * feeBasisPoints) / 10000;
        _active = o.active;
        _completed = o.completed;
    }

    function getUserTrades(address user)
        external
        view
        returns (uint256[] memory)
    {
        return tradeTracker[user];
    }

    function reclaimToken(IERC20 _token) external onlyOwner {
        uint256 balance = _token.balanceOf(address(this));
        uint256 excess = balance - balanceTracker[address(_token)];
        require(excess > 0);
        if (address(_token) == address(0)) {
            payable(msg.sender).transfer(excess);
        } else {
            _token.safeTransfer(owner(), excess);
        }
    }

    function claimFees(IERC20 _token) external onlyOwner {
        uint256 feesToClaim = feeTracker[address(_token)];
        feeTracker[address(_token)] = 0;
        require(feesToClaim > 0);
        if (address(_token) == address(0)) {
            payable(msg.sender).transfer(feesToClaim);
        } else {
            _token.safeTransfer(owner(), feesToClaim);
        }
    }
}