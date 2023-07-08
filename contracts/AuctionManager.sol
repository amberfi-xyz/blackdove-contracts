// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Openzeppelin
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
// Interfaces
import "./interfaces/IAuctionManager.sol";
import "./interfaces/IBlackdoveNFT.sol";
import "./interfaces/INFTPayoutsUpgradeable.sol";

// Errors
error FailedToCreateEnglishAuction(uint8 errorCode);
error FailedToClaimEnglishAuctionNFT(uint8 errorCode);
error FailedToBidToEnglishAuction(uint8 errorCode);
error FailedToCreateDutchAuction(uint8 errorCode);
error FailedToBuyFromDutchAuction(uint8 errorCode);
error InvalidFeeTier();
error InvalidFeeTierRecipient();
error InvalidFeeTiersSum();
error InvalidDiscountPercent();
error InvalidWithdrawAmount();
error NotBlackdoveNFT();
error NotTokenOwner(uint256 tokenId);
error TokenAlreadyClaimed(uint256 tokenId);
error ZeroAddress();

contract AuctionManager is
    IAuctionManager,
    Initializable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    enum AuctionType {
        English,
        Dutch
    }

    struct Bid {
        address bidder; // Bidder address
        uint256 bidAmount; // Bid amount
        uint256 bidAmountWithDiscount; // Bid amount with discount applied
    }

    struct EnglishAuction {
        uint256 startTimestamp; // Start tiemstamp
        uint256 endTimestamp; // End timestamp
        uint256 startPrice; // Start price
        uint256 reservedPrice; // Reserved price
        uint256 bidIncrementThreshold; // Bid increment threshold
        Bid highestBid; // Highest bid
    }

    struct DutchAuction {
        uint256 startTimestamp; // Start timestamp
        uint256 startPrice; // Start price
        uint256 floorPrice; // Floor price
        uint256 discountRate;
        uint256 discountInterval;
    }

    struct FeeTier {
        address feeRecipient; // Fee recipient address
        uint256 feeTier; // 1% = 100
    }

    IBlackdoveNFT private _blackdoveNFT; // Blackdove NFT contract
    EnglishAuction private _englishAuction; // English auction
    DutchAuction private _dutchAuction; // Dutch auction
    FeeTier[] private _feeTiers; // Service fee tier
    uint256 private _serviceFees; // Service fees collected
    uint256 private _numberOfDiscountWallets; // Number of discount wallets
    uint256 private _discountPercent; // Discount percent
    address private _feeRecipient; // Fee recipient
    uint256 private _feePercent; // Fee percent
    bool private _englishAuctionCreated; // English auction created
    bool private _englishAuctionEnded; // English auction ended
    mapping(uint256 => bool) private _tokenClaimed; // Token claimed status

    Bid[] public englishAuctionBids; // Array of english auction bids
    mapping(address => bool) public discountApplied; // Discount apply status
    mapping(uint256 => address) public tokenOwner; // Token owner

    // Events
    event BlackdoveNFTChanged(
        address indexed previousContract,
        address indexed newContract
    ); // Event emitted when BlackdoveNFT contract changed
    event NumberOfDiscountWalletsChanged(
        uint256 previousValue,
        uint256 newValue
    ); // Event emitted when number of discount wallets changed
    event DiscountPercentChanged(uint256 previousValue, uint256 newValue); // Event emitted when discount percent changed
    event EnglishAuctionCreated(
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 startPrice,
        uint256 reservedPrice,
        uint256 bidIncrementThreshold
    ); // Event emitted when english auction created
    event BidPlacedToEnglishAuction(address indexed bidder, uint256 bidAmount); // Event emitted when bid placed to english auction
    event ClaimedFromEnglishAuction(
        uint256 tokenId,
        address indexed winner,
        uint256 bidAmount
    ); // Event emitted when token claimed from english auction
    event DutchAuctionCreated(
        uint256 startTimestamp,
        uint256 startPrice,
        uint256 floorPrice,
        uint256 discountRate,
        uint256 discountInterval
    ); // Event emitted when dutch auction created
    event BoughtFromDutchAuction(
        uint256 tokenId,
        address indexed buyer,
        uint256 paymentAmount
    ); // Event emitted when token is bought from dutch auction
    event AuctionEnded(
        uint256 tokenId,
        address indexed winner,
        uint256 bidAmount
    ); // Event emitted when auction ended
    event FeeTierChanged(FeeTier[] feeTiers); // Event emitted when fee tiers changed

    /**
     * @dev Initializer
     * @param blackdoveNFT_ (address) Blackdove NFT contract address
     * @param feeTiers_ (FeeTier[] calldata) Service fee tiers
     * @param numberOfDiscountWallets_ (uint256) Number of discount wallets
     * @param discountPercent_ (uint256) Discount percent
     */
    function initialize(
        address blackdoveNFT_,
        FeeTier[] calldata feeTiers_,
        uint256 numberOfDiscountWallets_,
        uint256 discountPercent_
    ) public initializer {
        __Ownable2Step_init();
        setBlackdoveNFT(blackdoveNFT_);
        _setFeeTiers(feeTiers_);
        setNumberOfDiscountWallets(numberOfDiscountWallets_);
        setDiscountPercent(discountPercent_);
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
     * @dev Claim NFT item to change token URI
     * @param tokenId_ (uint256) Token ID to claim
     */
    function claimItem(uint256 tokenId_) external nonReentrant whenNotPaused {
        if (tokenOwner[tokenId_] != msg.sender) {
            revert NotTokenOwner(tokenId_);
        }

        if (_tokenClaimed[tokenId_]) {
            revert TokenAlreadyClaimed(tokenId_);
        }

        _tokenClaimed[tokenId_] = true;
    }

    /**
     * @dev Withdraw `amount_` of ETH. Only able to withdraw maximum of `_serviceFees` amount.
     * @param amount_ (uint256) ETH amount to withdraw
     */
    function withdrawETH(uint256 amount_) external onlyOwner {
        if (amount_ > address(this).balance) {
            revert InvalidWithdrawAmount();
        }

        if (_serviceFees < amount_) {
            revert InvalidWithdrawAmount();
        }

        _serviceFees -= amount_;

        payable(address(msg.sender)).transfer(amount_);
    }

    /**
     * @dev Create an english auction
     * @param startTimestamp_ (uint256) Start time of the auction in timestamp
     * @param endTimestamp_ (uint256) End time of the auction in timestamp
     * @param startPrice_ (uint256) Start price of the auction in ETH
     * @param reservedPrice_ (uint256) Reserved price of the auction in ETH
     * @param bidIncrementThreshold_ (uint256) Amount to increment when place next bid
     */
    function createEnglishAuction(
        uint256 startTimestamp_,
        uint256 endTimestamp_,
        uint256 startPrice_,
        uint256 reservedPrice_,
        uint256 bidIncrementThreshold_
    ) external nonReentrant whenNotPaused onlyOwner {
        if (_englishAuctionCreated) {
            revert FailedToCreateEnglishAuction(0); // ENGLISH_AUCTION_ALREADY_CREATED
        }

        if (
            startTimestamp_ < block.timestamp ||
            endTimestamp_ <= startTimestamp_
        ) {
            revert FailedToCreateEnglishAuction(1); // INVALID_TIME_RANGE
        }

        if (startPrice_ == 0) {
            revert FailedToCreateEnglishAuction(2); // INVALID_START_PRICE
        }

        if (reservedPrice_ < startPrice_) {
            revert FailedToCreateEnglishAuction(3); // INVALID_RESERVED_PRICE
        }

        if (bidIncrementThreshold_ > 10000 || bidIncrementThreshold_ == 0) {
            revert FailedToCreateEnglishAuction(4); // INVALID_BID_INCREMENT_THRESHOLD
        }

        uint256 currentTotalSupply = _blackdoveNFT.totalSupply();
        uint256 maxTotalSupply = _blackdoveNFT.maxTotalSupply();
        if (currentTotalSupply > maxTotalSupply) {
            revert FailedToCreateEnglishAuction(5); // EXCEED_MAX_TOTAL_SUPPLY
        }

        Bid memory highestBidder = Bid(address(0), 0, 0);
        EnglishAuction memory auction = EnglishAuction(
            startTimestamp_,
            endTimestamp_,
            startPrice_,
            reservedPrice_,
            bidIncrementThreshold_,
            highestBidder
        );
        _englishAuction = auction;
        _englishAuctionCreated = true;

        emit EnglishAuctionCreated(
            startTimestamp_,
            endTimestamp_,
            startPrice_,
            reservedPrice_,
            bidIncrementThreshold_
        );
    }

    /**
     * @dev Place bid to english auction
     */
    function placeBidToEnglishAuction()
        external
        payable
        nonReentrant
        whenNotPaused
    {
        uint256 mintPerWallet = _blackdoveNFT.mintPerWallet(msg.sender);
        uint256 maxMintPerWallet = _blackdoveNFT.maxMintPerWallet();
        if (mintPerWallet >= maxMintPerWallet) {
            revert FailedToBidToEnglishAuction(0); // EXCEED_MAX_MINT_PER_WALLET
        }

        EnglishAuction storage auction = _englishAuction;
        if (
            block.timestamp < auction.startTimestamp ||
            block.timestamp >= auction.endTimestamp
        ) {
            revert FailedToBidToEnglishAuction(1); // AUCTION_ENDED_OR_NOT_STARTED
        }

        uint256 minBidAmount = auction.highestBid.bidAmount > 0
            ? auction.highestBid.bidAmount
            : auction.startPrice;
        if (auction.highestBid.bidAmount > 0) {
            minBidAmount =
                (minBidAmount * (10000 + auction.bidIncrementThreshold)) /
                10000;
        }
        if (msg.value < minBidAmount) {
            revert FailedToBidToEnglishAuction(2); // Invalid bid amount
        }

        _blackdoveNFT.setMintPerWallet(msg.sender, mintPerWallet + 1);

        uint256 prevHighestBidAmount = auction.highestBid.bidAmount;
        address prevHighestBidder = auction.highestBid.bidder;

        Bid memory bid = Bid(msg.sender, msg.value, msg.value);

        englishAuctionBids.push(bid);
        auction.highestBid = bid;

        // Refund previous bid amount
        if (prevHighestBidAmount > 0 && prevHighestBidder != address(0)) {
            payable(address(prevHighestBidder)).transfer(prevHighestBidAmount);
        }

        emit BidPlacedToEnglishAuction(msg.sender, msg.value);
    }

    /**
     * @dev End english auction
     */
    function endEnglishAuction() external nonReentrant onlyOwner {
        EnglishAuction storage auction = _englishAuction;

        if (block.timestamp < auction.endTimestamp) {
            auction.endTimestamp = block.timestamp;
        }

        _englishAuctionEnded = true;

        address winner = auction.highestBid.bidder;
        uint256 winningAmount = auction.highestBid.bidAmount;
        if (winner != address(0)) {
            _setDiscountWallets();

            emit AuctionEnded(1, winner, winningAmount);
        } else {
            emit AuctionEnded(0, address(0), 0);
        }
    }

    /**
     * @dev Claim english auction NFT when auction is over
     */
    function claimEnglishAuctionNFT() external nonReentrant whenNotPaused {
        EnglishAuction memory auction = _englishAuction;

        if (block.timestamp < auction.endTimestamp) {
            revert FailedToClaimEnglishAuctionNFT(0); // Auction not ended
        }

        address winner = auction.highestBid.bidder;
        uint256 winningAmount = auction.highestBid.bidAmount;

        if (winner != msg.sender) {
            revert FailedToClaimEnglishAuctionNFT(1); // Not auction winner
        }

        uint256 tokenId = _blackdoveNFT.mint(msg.sender);
        address nftContract = address(_blackdoveNFT);
        address creator = INFTPayoutsUpgradeable(nftContract).creator(tokenId);
        uint256 bidAmountWithoutFee = (winningAmount * 10000) /
            (10000 + getServiceFeePercent());
        uint256 serviceFee = winningAmount - bidAmountWithoutFee;
        uint256 payoutCount;

        if (
            ERC165CheckerUpgradeable.supportsInterface(
                address(_blackdoveNFT),
                type(INFTPayoutsUpgradeable).interfaceId
            )
        ) {
            payoutCount = INFTPayoutsUpgradeable(nftContract).payoutCount(
                tokenId,
                creator == msg.sender
            );
        }

        address[] memory payoutReceivers = new address[](payoutCount);
        uint256[] memory payoutShares = new uint256[](payoutCount);

        _serviceFees += serviceFee;

        if (payoutCount > 0) {
            (payoutReceivers, payoutShares) = INFTPayoutsUpgradeable(
                nftContract
            ).payoutInfo(tokenId, bidAmountWithoutFee, creator == msg.sender);
            for (uint256 i; i < payoutCount; ) {
                payable(payoutReceivers[i]).transfer(payoutShares[i]);

                unchecked {
                    ++i;
                }
            }
        }

        FeeTier[] storage feeTiers = _feeTiers;
        uint256 feeTiersLength = feeTiers.length;
        uint256 feeTiersSum;

        for (uint256 i; i < feeTiersLength; ) {
            unchecked {
                feeTiersSum = feeTiersSum + _feeTiers[i].feeTier;
                ++i;
            }
        }

        for (uint256 i; i < feeTiersLength; ) {
            if (_feeTiers[i].feeRecipient == address(this)) continue;

            uint256 fee = (serviceFee * _feeTiers[i].feeTier) / feeTiersSum;
            payable(feeTiers[i].feeRecipient).transfer(fee);

            unchecked {
                ++i;
            }
        }

        emit ClaimedFromEnglishAuction(tokenId, msg.sender, winningAmount);
    }

    /**
     * @dev Create ductch auction
     * @param startTimestamp_ (uint256) Start time of the auction in timestamp
     * @param startPrice_ (uint256) Start price of the auction in ETH
     * @param floorPrice_ (uint256) Floor price of the auction in ETH
     * @param discountRate_ (uint256) Discount rate (1% = 100)
     * @param discountInterval_ (uint256) Discount interval in timestamp
     */
    function createDutchAuction(
        uint256 startTimestamp_,
        uint256 startPrice_,
        uint256 floorPrice_,
        uint256 discountRate_,
        uint256 discountInterval_
    ) external nonReentrant whenNotPaused onlyOwner {
        if (startTimestamp_ < block.timestamp) {
            revert FailedToCreateDutchAuction(0); // INVALID_START_TIMESTAMP
        }

        if (startPrice_ == 0) {
            revert FailedToCreateDutchAuction(1); // INVALID_START_PRICE
        }

        if (floorPrice_ == 0 || floorPrice_ > startPrice_) {
            revert FailedToCreateDutchAuction(2); // INVALID_FLOOR_PRICE
        }

        if (discountRate_ == 0 || discountRate_ > 9999) {
            revert FailedToCreateDutchAuction(3); // INVALID_DISCOUNT_RATE
        }

        if (discountInterval_ == 0) {
            revert FailedToCreateDutchAuction(4); // INVALID_DISCOUNT_INTERNAL
        }

        if (!_englishAuctionCreated || !_englishAuctionEnded) {
            revert FailedToCreateDutchAuction(5); // ENGLISH_AUCTION_NOT_CREATED_OR_ENDED
        }

        uint256 currentTotalSupply = _blackdoveNFT.totalSupply();
        uint256 maxTotalSupply = _blackdoveNFT.maxTotalSupply();
        if (currentTotalSupply > maxTotalSupply) {
            revert FailedToCreateDutchAuction(6); // EXCEED_MAX_TOTAL_SUPPLY
        }

        DutchAuction memory auction = DutchAuction(
            startTimestamp_,
            startPrice_,
            floorPrice_,
            discountRate_,
            discountInterval_
        );
        _dutchAuction = auction;

        emit DutchAuctionCreated(
            startTimestamp_,
            startPrice_,
            floorPrice_,
            discountRate_,
            discountInterval_
        );
    }

    /**
     * @dev Buy a dutch auction NFT
     */
    function buyFromDutchAuction() external payable nonReentrant whenNotPaused {
        uint256 mintPerWallet = _blackdoveNFT.mintPerWallet(msg.sender);
        uint256 maxMintPerWallet = _blackdoveNFT.maxMintPerWallet();
        if (mintPerWallet >= maxMintPerWallet) {
            revert FailedToCreateDutchAuction(0); // EXCEED_MAX_MINT_PER_WALLET
        }

        DutchAuction storage auction = _dutchAuction;
        if (block.timestamp < auction.startTimestamp) {
            revert FailedToBuyFromDutchAuction(1); // AUCTION_NOT_STARTED
        }

        uint256 price = getDutchAuctionPrice();
        uint256 discountedPrice = price;
        if (discountApplied[msg.sender]) {
            discountedPrice = (price * (10000 - _discountPercent)) / 10000;
            discountApplied[msg.sender] = false;
        }
        if (msg.value < discountedPrice) {
            revert FailedToBuyFromDutchAuction(2); // INVALID_PAYMENT_AMOUNT
        }

        _blackdoveNFT.setMintPerWallet(msg.sender, mintPerWallet + 1);

        uint256 tokenId = _blackdoveNFT.mint(msg.sender);
        address nftContract = address(_blackdoveNFT);
        address creator = INFTPayoutsUpgradeable(nftContract).creator(tokenId);
        uint256 discountedPriceWithFee = (discountedPrice * 10000) /
            (10000 + getServiceFeePercent());
        uint256 serviceFee = discountedPrice - discountedPriceWithFee;
        uint256 payoutCount;

        if (
            ERC165CheckerUpgradeable.supportsInterface(
                address(_blackdoveNFT),
                type(INFTPayoutsUpgradeable).interfaceId
            )
        ) {
            payoutCount = INFTPayoutsUpgradeable(nftContract).payoutCount(
                tokenId,
                creator == msg.sender
            );
        }

        address[] memory payoutReceivers = new address[](payoutCount);
        uint256[] memory payoutShares = new uint256[](payoutCount);

        _serviceFees += serviceFee;

        if (payoutCount > 0) {
            (payoutReceivers, payoutShares) = INFTPayoutsUpgradeable(
                nftContract
            ).payoutInfo(
                    tokenId,
                    discountedPriceWithFee,
                    creator == msg.sender
                );
            for (uint256 i; i < payoutCount; ) {
                payable(payoutReceivers[i]).transfer(payoutShares[i]);

                unchecked {
                    ++i;
                }
            }
        }

        FeeTier[] storage feeTiers = _feeTiers;
        uint256 feeTiersLength = feeTiers.length;
        uint256 feeTiersSum;

        for (uint256 i; i < feeTiersLength; ) {
            unchecked {
                feeTiersSum = feeTiersSum + _feeTiers[i].feeTier;
                ++i;
            }
        }

        for (uint256 i; i < feeTiersLength; ) {
            if (_feeTiers[i].feeRecipient == address(this)) continue;

            uint256 fee = (serviceFee * _feeTiers[i].feeTier) / feeTiersSum;
            payable(feeTiers[i].feeRecipient).transfer(fee);

            unchecked {
                ++i;
            }
        }

        emit BoughtFromDutchAuction(tokenId, msg.sender, msg.value);
        emit AuctionEnded(tokenId, msg.sender, msg.value);
    }

    function setBlackdoveNFT(address blackdoveNFT_) public onlyOwner {
        if (blackdoveNFT_ == address(0)) {
            revert ZeroAddress();
        }
        IBlackdoveNFT prev = _blackdoveNFT;
        _blackdoveNFT = IBlackdoveNFT(blackdoveNFT_);

        emit BlackdoveNFTChanged(address(prev), blackdoveNFT_);
    }

    /**
     * @dev Set service fee tiers
     * @param feeTiers_ (FeeTier[] calldata) New service fee tiers
     */
    function setFeeTiers(FeeTier[] calldata feeTiers_) external onlyOwner {
        _setFeeTiers(feeTiers_);
    }

    /**
     * @dev Set number of discount wallets
     * @param numberOfDiscountWallets_ (uint256) Number of discount wallets
     */
    function setNumberOfDiscountWallets(
        uint256 numberOfDiscountWallets_
    ) public onlyOwner {
        uint256 prev = _numberOfDiscountWallets;
        _numberOfDiscountWallets = numberOfDiscountWallets_;

        emit NumberOfDiscountWalletsChanged(prev, numberOfDiscountWallets_);
    }

    /**
     * @dev Set discount percent
     * @param discountPercent_ (uint256) Discount percent
     */
    function setDiscountPercent(uint256 discountPercent_) public onlyOwner {
        if (discountPercent_ > 10000) {
            revert InvalidDiscountPercent();
        }
        uint256 prev = _discountPercent;
        _discountPercent = discountPercent_;

        emit DiscountPercentChanged(prev, discountPercent_);
    }

    /**
     * @dev Get english auction object detail
     * @return (uint256) Start time
     * @return (uint256) End time
     * @return (uint256) Start price
     * @return (uint256) Reserved price
     * @return (uint256) Bid increment threshold
     * @return (address) Highest bidder
     * @return (bool) Highest bid amount
     */
    function getEnglishAuction()
        public
        view
        returns (uint256, uint256, uint256, uint256, uint256, address, uint256)
    {
        EnglishAuction memory englishAuction = _englishAuction;

        return (
            englishAuction.startTimestamp,
            englishAuction.endTimestamp,
            englishAuction.startPrice,
            englishAuction.reservedPrice,
            englishAuction.bidIncrementThreshold,
            englishAuction.highestBid.bidder,
            englishAuction.highestBid.bidAmount
        );
    }

    /**
     * @dev Get english auction price
     * @return (uint256) Auction price
     */
    function getEnglishAuctionPrice() public view returns (uint256) {
        EnglishAuction memory englishAuction = _englishAuction;

        return
            englishAuction.highestBid.bidAmount == 0
                ? englishAuction.startPrice
                : englishAuction.highestBid.bidAmount;
    }

    /**
     * @dev Get dutch auction object detail
     * @return (uint256) Start time
     * @return (uint256) Start price
     * @return (uint256) Floor price
     * @return (uint256) Discount rate
     * @return (uint256)discount rate
     */
    function getDutchAuction()
        public
        view
        returns (uint256, uint256, uint256, uint256, uint256)
    {
        DutchAuction memory dutchAuction = _dutchAuction;

        return (
            dutchAuction.startTimestamp,
            dutchAuction.startPrice,
            dutchAuction.floorPrice,
            dutchAuction.discountRate,
            dutchAuction.discountInterval
        );
    }

    /**
     * @dev Get dutch auction price
     * @return (uint256) Auction price
     */
    function getDutchAuctionPrice() public view returns (uint256) {
        DutchAuction memory dutchAuction = _dutchAuction;

        uint256 timeElapsed = block.timestamp - dutchAuction.startTimestamp;
        uint256 discounts = timeElapsed / dutchAuction.discountInterval;
        uint256 price = (dutchAuction.startPrice *
            ((10000 - dutchAuction.discountRate) ** discounts)) /
            (10000 ** discounts);

        return
            price > dutchAuction.floorPrice ? price : dutchAuction.floorPrice;
    }

    /**
     * @dev Get service fee percent
     * @return (uint256) Service fee percent
     */
    function getServiceFeePercent() public view returns (uint256) {
        uint256 feeTiersLength = _feeTiers.length;
        uint256 feeTiersSum;

        unchecked {
            for (uint256 i; i < feeTiersLength; ++i) {
                feeTiersSum = feeTiersSum + _feeTiers[i].feeTier;
            }
        }

        return feeTiersSum;
    }

    /**
     * @dev Get status of english auction creation
     * @return (bool) Auction created
     */
    function englishAuctionCreated() external view returns (bool) {
        return _englishAuctionCreated;
    }

    /**
     * @dev Add wallet `wallet_` to the discount list
     * @param wallet_ (address) Wallet address
     */
    function addToDiscountList(address wallet_) external onlyOwner {
        discountApplied[wallet_] = true;
    }

    /**
     * @dev Get discount information
     * @return (uint256) Number of discount wallets
     * @return (uint256) Discount percent
     */
    function getDiscount() external view returns (uint256, uint256) {
        return (_numberOfDiscountWallets, _discountPercent);
    }

    /**
     * @dev Get service fee tiers
     * @return (FeeTier[] memory) Fee tiers
     */
    function getFeeTiers() external view returns (FeeTier[] memory) {
        return _feeTiers;
    }

    /**
     * @dev Get the token claim status
     * @param tokenId_ (uint256) Token ID
     * @return (bool) Token claim status
     */
    function tokenClaimed(uint256 tokenId_) external view returns (bool) {
        return _tokenClaimed[tokenId_];
    }

    /**
     * @dev Set discount wallets
     */
    function _setDiscountWallets() private {
        uint256 count;
        uint256 length = englishAuctionBids.length;
        address[] memory uniqueAddresses = new address[](length);

        for (int256 i = (int256)(length - 1); i >= 0; --i) {
            bool isDuplicate;
            for (uint256 j; j < count; ++j) {
                if (
                    uniqueAddresses[j] ==
                    englishAuctionBids[(uint256)(i)].bidder
                ) {
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate) {
                uniqueAddresses[count] = englishAuctionBids[(uint256)(i)]
                    .bidder;
                count++;
                if (count >= _numberOfDiscountWallets) {
                    break;
                }
            }
        }

        for (uint256 i; i < count; ++i) {
            discountApplied[uniqueAddresses[i]] = true;
        }
    }

    /**
     * @dev Set service fee tiers
     * @param feeTiers_ (FeeTier[] calldata) New service fee tiers
     */
    function _setFeeTiers(FeeTier[] calldata feeTiers_) private {
        uint256 feeTiersLength = feeTiers_.length;
        uint256 feeTiersSum;

        for (uint256 i; i < feeTiersLength; ) {
            if (feeTiers_[i].feeRecipient == address(0)) {
                revert InvalidFeeTierRecipient();
            }

            if (feeTiers_[i].feeTier == 0) {
                revert InvalidFeeTier();
            }

            unchecked {
                feeTiersSum = feeTiersSum + feeTiers_[i].feeTier;
                ++i;
            }
        }

        if (feeTiersLength > 0 && feeTiersSum > 9999) {
            revert InvalidFeeTiersSum();
        }

        delete _feeTiers;

        for (uint256 i; i < feeTiersLength; ) {
            _feeTiers.push(
                FeeTier(feeTiers_[i].feeRecipient, feeTiers_[i].feeTier)
            );

            unchecked {
                ++i;
            }
        }

        emit FeeTierChanged(feeTiers_);
    }
}
