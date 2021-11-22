//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract EmiTracking is OwnableUpgradeable {
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

    struct UserStake {
        uint256 stakeAmount;
        uint256 stakeDate;
        uint256 enterRequestId;
    }

    // wallet => userStake
    mapping(address => UserStake) public userStakes;

    /**
     * @dev events
     */
    event Entered(address wallet, uint256 stakeAmount, uint256 enterRequestId);

    function initialize(address owner, address inputStakeToken)
        public
        virtual
        initializer
    {
        __Ownable_init();
        transferOwnership(owner);
        stakeToken = IERC20Upgradeable(inputStakeToken);
    }

    /**
    Принимать ставку от пользователя;
    Создавать запрос (request), взаимодействуя:
    на вход: с контрактом Token Request Арагона;    

    Получать номер запроса и сохранять его вместе с информацией о ставке в реестре, обеспечив тем самым маппинг ставки пользователя и запроса в Березку.
     */
    function enter(uint256 amount) public {
        require(amount > 0, "incorrect amount");
        uint256 requestId = 0; // get reuqestId from berezka DAO
        userStakes[msg.sender] = UserStake(amount, block.timestamp, requestId);
        stakeToken.transferFrom(msg.sender, address(this), amount);
        emit Entered(msg.sender, amount, requestId);
    }

    /**
    Создавать запрос (request) на выход: с контрактом DeversiFi.
     */
    function exitRequest() public {}

    /**
    Возвращать фронту список всех запросов (идентификаторов) пользователя
     */
    function getUsersEnterRequests() public view {}

    /**
    Отдавать во фронт информацию о запросе по его идентификатору. Фронт получает идентификатор либо из списка (см п. 4), либо из события.
     */
    function getEnterRequestData() public view {}

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