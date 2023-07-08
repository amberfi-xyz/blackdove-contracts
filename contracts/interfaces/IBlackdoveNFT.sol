// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IBlackdoveNFT
 * @dev Interface for BlackdoveNFT contract
 * @author kazunetakeda25
 */
interface IBlackdoveNFT {
    /**
     * @dev Return max mint per wallet
     * @return (uint256) Number of max mint per wallet
     */
    function maxMintPerWallet() external view returns (uint256);

    /**
     * @dev Get mint per wallet for `account_`
     * @param account_ (address) Account to get
     * @return (uint256) Number of mint per wallet
     */
    function mintPerWallet(address account_) external view returns (uint256);

    /**
     * @dev Set mint per wallet
     * @param account_ (address) Account to set
     * @param mintPerWallet_ (uint256) Number of mint per wallet
     */
    function setMintPerWallet(
        address account_,
        uint256 mintPerWallet_
    ) external;

    /**
     * @dev Mint an NFT to `to_` (called by Auction Manager)
     * @param to_ (address) Mint to address
     * @return (uint256) Minted token ID
     */
    function mint(address to_) external returns (uint256);

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     * @return (uint256) Total supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the max total supply of the contract.
     * @return (uint256) Max total supply
     */
    function maxTotalSupply() external view returns (uint256);
}
