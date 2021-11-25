//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITokenRequest {
    enum Status {
        Pending,
        Refunded,
        Finalised
    }

    struct TokenRequestData {
        address requesterAddress;
        address depositToken;
        uint256 depositAmount;
        uint256 requestAmount;
        Status status;
    }

    //mapping(uint256 => TokenRequestData) public tokenRequests; // ID => TokenRequest

    function tokenRequests(uint256 id)
        external
        view
        returns (TokenRequestData memory tokenRequestData);

    function createTokenRequest(
        address _depositToken,
        uint256 _depositAmount,
        uint256 _requestAmount,
        string memory _reference
    ) external payable returns (uint256);
}
