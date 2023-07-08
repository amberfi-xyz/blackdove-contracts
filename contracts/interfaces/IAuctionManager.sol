// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAuctionManager
 * @dev Interface for AuctionManager contract
 * @author kazunetakeda25
 */
interface IAuctionManager {
    /**
     * @dev Get the token claim status
     * @param tokenId_ (uint256) Token ID
     * @return (bool) Token claim status
     */
    function tokenClaimed(uint256 tokenId_) external view returns (bool);
}
