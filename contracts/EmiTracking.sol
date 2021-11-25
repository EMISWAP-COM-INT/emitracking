//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./ITokenRequest.sol";

contract EmiTracking is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ITokenRequest public tokenRequest;

    enum InStages {
        PENDING,
        REFUNDED,
        FINALISED
    }
    enum OutStages {
        PENDING,
        FINALISED,
        COLLECTED,
        CANCELED
    }

    IERC20Upgradeable public stakeToken;

    struct EnterRequestData {
        uint256 stakeAmount;
        uint256 stakeDate;
        InStages enterStage;
    }

    // requestId => wallet
    mapping(uint256 => address) public requestWallet;
    // wallet => requsetIds
    mapping(address => uint256[]) public walletRequests;
    // requestId => requset data array
    mapping(uint256 => EnterRequestData) public requestIdData;

    /**
     * @dev events
     */
    event Entered(
        address wallet,
        uint256 stakeAmount,
        uint256 requestedAmount,
        uint256 enterRequestId
    );

    function initialize(
        address _owner,
        address _stakeToken,
        address _tokenRequest
    ) public virtual initializer {
        __Ownable_init();
        transferOwnership(_owner);
        stakeToken = IERC20Upgradeable(_stakeToken);
        tokenRequest = ITokenRequest(_tokenRequest);
    }

    /**
    Принимать ставку от пользователя;
    Создавать запрос (request), взаимодействуя:
    на вход: с контрактом Token Request Арагона;    

    Получать номер запроса и сохранять его вместе с информацией о ставке в реестре, обеспечив тем самым маппинг ставки пользователя и запроса в Березку.
     */
    function enter(uint256 amount, uint256 requestedAmount) public {
        require(amount > 0, "incorrect amount");

        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        stakeToken.safeApprove(address(tokenRequest), amount);
        uint256 requestId = tokenRequest.createTokenRequest(
            address(stakeToken),
            amount,
            requestedAmount,
            ""
        ); // get reuqestId from berezka DAO

        walletRequests[msg.sender].push(requestId);
        requestWallet[requestId] = msg.sender;
        requestIdData[requestId] = EnterRequestData(
            amount,
            block.timestamp,
            InStages.PENDING
        );

        emit Entered(msg.sender, amount, requestedAmount, requestId);
    }

    /**
    Создавать запрос (request) на выход: с контрактом DeversiFi.
     */
    function exitRequest(uint256 requestId) public {}

    /**
    Возвращать фронту список всех запросов (идентификаторов) пользователя
     */
    function getUsersEnterRequests() public view {}

    /**
    Отдавать во фронт информацию о запросе по его идентификатору. Фронт получает идентификатор либо из списка (см п. 4), либо из события.
     */
    function getEnterRequestData(uint256 requestId)
        public
        view
        returns (
            address wallet,
            uint256 amount,
            InStages stage
        )
    {
        wallet = requestWallet[requestId];
        amount = requestIdData[requestId].stakeAmount;
        stage = requestIdData[requestId].enterStage;
    }

    /**
    Выдать список запросов на вход по кошельку
     */
    function getWalletEnterRequests(address wallet)
        public
        view
        returns (uint256[] memory reuestIds)
    {
        return walletRequests[wallet];
    }

    /**
     * @dev getting enter stake data (struct TokenRequestData) + status (enum Status) by request id
     * @param id request id 
     * @return requesterAddress requester address (always this contract)
     * @return depositToken deposite token
     * @return depositAmount deposite token amount
     * @return requestAmount requested token amount
     * @return status int representation of aragons enum Status {Pending, Refunded, Finalised}
     */
    function getEnterRequest(uint256 id)
        public
        view
        returns (
            address requesterAddress,
            address depositToken,
            uint256 depositAmount,
            uint256 requestAmount,
            uint256 status
        )
    {
        requesterAddress = tokenRequest.tokenRequests(id).requesterAddress;
        depositToken = tokenRequest.tokenRequests(id).depositToken;
        depositAmount = tokenRequest.tokenRequests(id).depositAmount;
        requestAmount = tokenRequest.tokenRequests(id).requestAmount;
        status = uint256(tokenRequest.tokenRequests(id).status);
    }

    /**
    Возвращать пользователю на кошелек токены по одному из сценариев:
        USDT остались на контракте Token Request Арагона, т.к. запрос на вход был отклонен.
        USDT вернулись на трекинг-контракт, т.к. запрос на выход был акцептован. Определять прибыль и удерживать комиссию.
     */
    function getExitStatus() public view {}

    /**
    Определять прибыль по ставке на основании информации о запросе.
     */
    function calculateRequestProfit() public view {}

    /**
    Направлять 20% прибыли по запросу на выход на кошелек EmiSwap.
    Возвращать пользователю сумму USDT  + 80% прибыли по запросу на выход.
     */
    function exitFinalize() public {}
}
