//SPDX-License-Identifier: MIT
/**
 * @dev prepared mock version of Aragon staking contract to use in tests
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./lib/UintArrayLib.sol";
import "./lib/AddressArrayLib.sol";

/**
 * The expected use of this app requires the FINALISE_TOKEN_REQUEST_ROLE permission be given exclusively to a forwarder.
 * A user can then request tokens by calling createTokenRequest() to deposit funds and then calling finaliseTokenRequest()
 * which will be called via the forwarder if forwarding is successful, minting the user tokens.
 */
contract TokenRequest {
    using SafeERC20 for ERC20;
    using UintArrayLib for uint256[];
    using AddressArrayLib for address[];

    bytes32 public constant SET_TOKEN_MANAGER_ROLE =
        keccak256("SET_TOKEN_MANAGER_ROLE");
    bytes32 public constant SET_VAULT_ROLE = keccak256("SET_VAULT_ROLE");
    bytes32 public constant FINALISE_TOKEN_REQUEST_ROLE =
        keccak256("FINALISE_TOKEN_REQUEST_ROLE");
    bytes32 public constant MODIFY_TOKENS_ROLE =
        keccak256("MODIFY_TOKENS_ROLE");

    string private constant ERROR_TOO_MANY_ACCEPTED_TOKENS =
        "TOKEN_REQUEST_TOO_MANY_ACCEPTED_TOKENS";
    string private constant ERROR_ADDRESS_NOT_CONTRACT =
        "TOKEN_REQUEST_ADDRESS_NOT_CONTRACT";
    string private constant ERROR_ACCEPTED_TOKENS_MALFORMED =
        "TOKEN_REQUEST_ACCEPTED_TOKENS_MALFORMED";
    string private constant ERROR_TOKEN_ALREADY_ACCEPTED =
        "TOKEN_REQUEST_TOKEN_ALREADY_ACCEPTED";
    string private constant ERROR_TOKEN_NOT_ACCEPTED =
        "TOKEN_REQUEST_TOKEN_NOT_ACCEPTED";
    string private constant ERROR_NOT_OWNER = "TOKEN_REQUEST_NOT_OWNER";
    string private constant ERROR_NOT_PENDING = "TOKEN_REQUEST_NOT_PENDING";
    string private constant ERROR_ETH_VALUE_MISMATCH =
        "TOKEN_REQUEST_ETH_VALUE_MISMATCH";
    string private constant ERROR_ETH_TRANSFER_FAILED =
        "TOKEN_REQUEST_ETH_TRANSFER_FAILED";
    string private constant ERROR_TOKEN_TRANSFER_REVERTED =
        "TOKEN_REQUEST_TOKEN_TRANSFER_REVERTED";
    string private constant ERROR_NO_REQUEST = "TOKEN_REQUEST_NO_REQUEST";

    uint256 public constant MAX_ACCEPTED_DEPOSIT_TOKENS = 100;

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

    address public vault;

    address[] public acceptedDepositTokens;

    uint256 public nextTokenRequestId;
    mapping(uint256 => TokenRequestData) public tokenRequests; // ID => TokenRequest

    event SetVault(address vault);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event TokenRequestCreated(
        uint256 requestId,
        address requesterAddress,
        address depositToken,
        uint256 depositAmount,
        uint256 requestAmount,
        string referenceString
    );
    event TokenRequestRefunded(
        uint256 requestId,
        address refundToAddress,
        address refundToken,
        uint256 refundAmount
    );
    event TokenRequestFinalised(
        uint256 requestId,
        address requester,
        address depositToken,
        uint256 depositAmount,
        uint256 requestAmount
    );

    modifier tokenRequestExists(uint256 _tokenRequestId) {
        require(_tokenRequestId < nextTokenRequestId, ERROR_NO_REQUEST);
        _;
    }

    /**
     * @notice Initialize TokenRequest app contract
     * @param _vault Vault address
     * @param _acceptedDepositTokens Unique list of redeemable tokens is ascending order
     */
    function initialize(address _vault, address[] memory _acceptedDepositTokens)
        public
    {
        require(
            _acceptedDepositTokens.length <= MAX_ACCEPTED_DEPOSIT_TOKENS,
            ERROR_TOO_MANY_ACCEPTED_TOKENS
        );

        for (uint256 i = 0; i < _acceptedDepositTokens.length; i++) {
            if (i >= 1) {
                require(
                    _acceptedDepositTokens[i - 1] < _acceptedDepositTokens[i],
                    ERROR_ACCEPTED_TOKENS_MALFORMED
                );
            }
        }

        vault = _vault;
        acceptedDepositTokens = _acceptedDepositTokens;
    }

    /**
     * @notice Add `_token.symbol(): string` to the accepted deposit token request tokens
     * @param _token token address
     */
    function addToken(address _token) external {
        /* require(!acceptedDepositTokens.contains(_token), ERROR_TOKEN_ALREADY_ACCEPTED);
        require(acceptedDepositTokens.length < MAX_ACCEPTED_DEPOSIT_TOKENS, ERROR_TOO_MANY_ACCEPTED_TOKENS); */

        acceptedDepositTokens.push(_token);

        emit TokenAdded(_token);
    }

    /**
     * @notice Remove `_token.symbol(): string` from the accepted deposit token request tokens
     * @param _token token address
     */
    function removeToken(address _token) external {
        /* require(acceptedDepositTokens.deleteItem(_token), ERROR_TOKEN_NOT_ACCEPTED); */

        emit TokenRemoved(_token);
    }

    /**
     * @notice Create a token request depositing `@tokenAmount(_depositToken, _depositAmount, true)` in exchange for `@tokenAmount(self.getToken(): address, _requestAmount, true)`
     * @param _depositToken Address of the token being deposited
     * @param _depositAmount Amount of the token being deposited
     * @param _requestAmount Amount of the token being requested
     * @param _reference String detailing request reason
     */
    function createTokenRequest(
        address _depositToken,
        uint256 _depositAmount,
        uint256 _requestAmount,
        string memory _reference
    ) external payable returns (uint256) {
        require(
            acceptedDepositTokens.contains(_depositToken),
            ERROR_TOKEN_NOT_ACCEPTED
        );

        ERC20(_depositToken).safeTransferFrom(
            msg.sender,
            address(this),
            _depositAmount
        );

        uint256 tokenRequestId = nextTokenRequestId;
        nextTokenRequestId++;

        tokenRequests[tokenRequestId] = TokenRequestData(
            msg.sender,
            _depositToken,
            _depositAmount,
            _requestAmount,
            Status.Pending
        );

        emit TokenRequestCreated(
            tokenRequestId,
            msg.sender,
            _depositToken,
            _depositAmount,
            _requestAmount,
            _reference
        );

        return tokenRequestId;
    }

    /**
     * @notice Refund `@tokenAmount(self.getTokenRequest(_tokenRequestId): (address, <address>), self.getTokenRequest(_tokenRequestId): (address, address, <uint>, uint))` to `self.getTokenRequest(_tokenRequestId): address`, this will invalidate the request for `@tokenAmount(self.getToken(): address, self.getTokenRequest(_tokenRequestId): (address, address, uint, <uint>))`
     * @param _tokenRequestId ID of the Token Request
     */
    function refundTokenRequest(uint256 _tokenRequestId)
        external
        tokenRequestExists(_tokenRequestId)
    {
        TokenRequestData storage tokenRequest = tokenRequests[_tokenRequestId];
        require(tokenRequest.requesterAddress == msg.sender, ERROR_NOT_OWNER);
        require(tokenRequest.status == Status.Pending, ERROR_NOT_PENDING);

        tokenRequest.status = Status.Refunded;

        address refundToAddress = tokenRequest.requesterAddress;
        address refundToken = tokenRequest.depositToken;
        uint256 refundAmount = tokenRequest.depositAmount;

        if (refundAmount > 0) {
            ERC20(refundToken).safeTransfer(refundToAddress, refundAmount);
        }

        emit TokenRequestRefunded(
            _tokenRequestId,
            refundToAddress,
            refundToken,
            refundAmount
        );
    }

    /**
     * @notice Approve  `self.getTokenRequest(_tokenRequestId): address`'s request for `@tokenAmount(self.getToken(): address, self.getTokenRequest(_tokenRequestId): (address, address, uint, <uint>))` in exchange for `@tokenAmount(self.getTokenRequest(_tokenRequestId): (address, <address>), self.getTokenRequest(_tokenRequestId): (address, address, <uint>, uint))`
     * @dev This function's FINALISE_TOKEN_REQUEST_ROLE permission is typically given exclusively to a forwarder.
     *      This function requires the MINT_ROLE permission on the TokenManager specified.
     * @param _tokenRequestId ID of the Token Request
     */
    function finaliseTokenRequest(uint256 _tokenRequestId)
        external
        tokenRequestExists(_tokenRequestId)
    {
        TokenRequestData storage tokenRequest = tokenRequests[_tokenRequestId];
        require(tokenRequest.status == Status.Pending, ERROR_NOT_PENDING);

        tokenRequest.status = Status.Finalised;

        address requesterAddress = tokenRequest.requesterAddress;
        address depositToken = tokenRequest.depositToken;
        uint256 depositAmount = tokenRequest.depositAmount;
        uint256 requestAmount = tokenRequest.requestAmount;

        if (depositAmount > 0) {
            ERC20(depositToken).safeTransfer(vault, depositAmount);
        }

        emit TokenRequestFinalised(
            _tokenRequestId,
            requesterAddress,
            depositToken,
            depositAmount,
            requestAmount
        );
    }

    function getAcceptedDepositTokens() public view returns (address[] memory) {
        return acceptedDepositTokens;
    }

    function getTokenRequest(uint256 _tokenRequestId)
        public
        view
        returns (
            address requesterAddress,
            address depositToken,
            uint256 depositAmount,
            uint256 requestAmount
        )
    {
        TokenRequestData storage tokenRequest = tokenRequests[_tokenRequestId];

        requesterAddress = tokenRequest.requesterAddress;
        depositToken = tokenRequest.depositToken;
        depositAmount = tokenRequest.depositAmount;
        requestAmount = tokenRequest.requestAmount;
    }
}
