// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Openzeppelin
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
// Utils
import "./utils/NFTPayoutsUpgradeable.sol";
// Interfaces
import "./interfaces/IAuctionManager.sol";
import "./interfaces/IBlackdoveNFT.sol";

// Errors
error ExceedTotalSupply();
error FailedToCreateEnglishAUction(uint8 errorCOde);
error FailedToCreateDutchAuction(uint8 errorType);
error InvalidNumber(
    uint256 invalidNumber,
    uint256 minNumber,
    uint256 maxNumber
);
error InvalidTokenID();
error NotAuctionManager();
error ZeroAddress();

/**
 * @title BlackdoveNFT
 * @dev Blackdove Marketplace Collection contract
 * @author kazunetakeda25
 */
contract BlackdoveNFT is
    IBlackdoveNFT,
    Initializable,
    ERC721Upgradeable,
    NFTPayoutsUpgradeable,
    Ownable2StepUpgradeable,
    PausableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;

    CountersUpgradeable.Counter private _tokenIdCounter; // Token ID counter
    IAuctionManager private _auctionManager; // Auction Manager contract
    uint256 private _maxMintPerWallet; // Max mint per wallet
    uint256 private _maxTotalSupply; // Max total supply
    uint256 private _royaltyBPS; // Royalty BPS
    address private _royaltyReceiver; // Royalty receiver
    string private _baseURIClaimed; // Base URI of claimed tokens
    mapping(address => uint256) private _mintsPerWallet; // Mint per wallet

    string public baseURI; // Base URI

    // Events
    event AuctionManagerChanged(
        address indexed previousContract,
        address indexed newContract
    ); // Event emitted when auction manager changed
    event BaseURIChanged(uint256 id, string baseURI); // Event emitted when base URI changed
    event MaxMintPerWalletChanged(uint256 maxMintPerWallet); // Event emitted when max mint per wallet changed
    event NFTMinted(address indexed to, uint256 tokenId); // Event emitted when NFT minted

    /**
     * @dev Modifier to check if caller is auction manager
     */
    modifier onlyAuctionManager() {
        if (msg.sender != address(_auctionManager)) {
            revert NotAuctionManager();
        }
        _;
    }

    /**
     * @dev Initializer
     * @param name_ (string calldata) Collection name
     * @param symbol_ (string calldata) Collection symbol
     * @param baseURI_ (string calldata) Collection base URI
     * @param baseURIClaimed_ (string calldata) Collection base URI for claimed tokens
     * @param maxMintPerWallet_ (uint256) Collection max mint per wallet
     * @param maxTotalSupply_ (uint256) Collection max total supply
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        string calldata baseURI_,
        string calldata baseURIClaimed_,
        uint256 maxMintPerWallet_,
        uint256 maxTotalSupply_
    ) public initializer {
        __Ownable2Step_init();
        __ERC721_init(name_, symbol_);
        _setBaseURI(baseURI_);
        _setBaseURIClaimed(baseURIClaimed_);
        setMaxMintPerWallet(maxMintPerWallet_);
        _maxTotalSupply = maxTotalSupply_;
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Set Auction Manager contract address
     * @param auctionManager_ (address) Auction Manager contract address
     */
    function setAuctionManager(address auctionManager_) external onlyOwner {
        if (auctionManager_ == address(0)) {
            revert ZeroAddress();
        }

        IAuctionManager prev = _auctionManager;
        _auctionManager = IAuctionManager(auctionManager_);

        emit AuctionManagerChanged(address(prev), auctionManager_);
    }

    /**
     * @dev Set the base URI
     * @param baseURI_ (string calldata) base URI
     */
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _setBaseURI(baseURI_);
    }

    /**
     * @dev Set the base URI for claimed tokens
     * @param baseURIClaimed_ (string calldata) base URI for claimed tokens
     */
    function setBaseURIClaimed(
        string memory baseURIClaimed_
    ) external onlyOwner {
        _setBaseURIClaimed(baseURIClaimed_);
    }

    /**
     * @dev Set mint per wallet
     * @param account_ (address) Account to set
     * @param mintPerWallet_ (uint256) Number of mint per wallet
     */
    function setMintPerWallet(
        address account_,
        uint256 mintPerWallet_
    ) external onlyAuctionManager {
        _mintsPerWallet[account_] = mintPerWallet_;
    }

    /**
     * @dev Mint an NFT to `to_` (called by Auction Manager)
     * @param to_ (address) Mint to address
     * @return (uint256) Minted token ID
     */
    function mint(address to_) external onlyAuctionManager returns (uint256) {
        _tokenIdCounter.increment();

        uint256 tokenId = _tokenIdCounter.current();

        _mint(to_, tokenId);

        return tokenId;
    }

    /**
     * @dev Return max mint per wallet
     * @return (uint256) Number of max mint per wallet
     */
    function maxMintPerWallet() public view returns (uint256) {
        return _maxMintPerWallet;
    }

    /**
     * @dev Get mint per wallet for `account_`
     * @param account_ (address) Account to get
     * @return (uint256) Number of mint per wallet
     */
    function mintPerWallet(address account_) public view returns (uint256) {
        return _mintsPerWallet[account_];
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId_
    )
        public
        view
        virtual
        override(ERC721Upgradeable, NFTPayoutsUpgradeable)
        returns (bool)
    {
        return
            interfaceId_ == type(NFTPayoutsUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId_);
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     * @param tokenId_ (uint256) Token ID
     * @return (string memory) Token URI
     */
    function tokenURI(
        uint256 tokenId_
    ) public view override returns (string memory) {
        if (!_exists(tokenId_)) {
            revert InvalidTokenID();
        }

        bool claimed = _auctionManager.tokenClaimed(tokenId_);
        string memory tokenBaseURI = claimed ? _baseURIClaimed : baseURI;

        return
            bytes(tokenBaseURI).length > 0
                ? string(abi.encodePacked(tokenBaseURI, tokenId_.toString()))
                : "";
    }

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     * @return (uint256) Total supply
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * @dev Returns the max total supply of the contract.
     * @return (uint256) Max total supply
     */
    function maxTotalSupply() public view returns (uint256) {
        return _maxTotalSupply;
    }

    /**
     * @dev Set max mint per wallet
     * @param maxMintPerWallet_ (uint256) Number of max mint per wallet
     */
    function setMaxMintPerWallet(uint256 maxMintPerWallet_) public onlyOwner {
        _maxMintPerWallet = maxMintPerWallet_;

        emit MaxMintPerWalletChanged(maxMintPerWallet_);
    }

    /**
     * @dev Set the base URI
     * @param baseURI_ (string calldata) base URI
     */
    function _setBaseURI(string memory baseURI_) private {
        baseURI = baseURI_;

        emit BaseURIChanged(0, baseURI_);
    }

    /**
     * @dev Set the base URI for claimed tokens
     * @param baseURIClaimed_ (string calldata) base URI for claimed tokens
     */
    function _setBaseURIClaimed(string memory baseURIClaimed_) private {
        _baseURIClaimed = baseURIClaimed_;

        emit BaseURIChanged(1, _baseURIClaimed);
    }
}
