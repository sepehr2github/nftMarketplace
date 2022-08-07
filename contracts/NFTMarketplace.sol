// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

error NFTMarketplace_PriceMustBeAboveZero();
error NFTMarketplace_NotApprovedForMarketplace();
error NFTMarketplace_AlreadyListed(address nftAddress, uint256 tokenId);
error NFTMarketplace_NotListed(address nftAddress, uint256 tokenId);
error NFTMarketplace_PriceNotMet(
	address nftAddress,
	uint256 tokenId,
	uint256 price
);
error NFTMarketplace_NotOwner();
error NFTMarketplace_NoProceeds();
error NFTMarketplace__TransferFailed();

contract NFTMarketplace is ReentrancyGuard {
	struct Listing {
		uint256 price;
		address seller;
	}

	//////////////////
	///// Events /////
	//////////////////

	event ItemListed(
		address indexed seller,
		address indexed nftAddress,
		uint256 indexed tokenId,
		uint256 price
	);

	event itemBought(
		address indexed buyer,
		address indexed nftAddress,
		uint256 indexed tokenId,
		uint256 price
	);

	event ItemCanceled(
		address indexed seller,
		address indexed nftAddress,
		uint256 indexed tokenId
	);

	//////////////////

	//NFT contract address -> NFT token id -> Listing
	mapping(address => mapping(uint256 => Listing)) private s_listings;
	// seller address -> Amount earned
	mapping(address => uint256) private s_proceeds;

	//////////////////
	//// Modifier ////
	//////////////////

	modifier notListed(
		address nftAddress,
		uint256 tokenId,
		address owner
	) {
		Listing memory listing = s_listings[nftAddress][tokenId];
		if (listing.price > 0)
			revert NFTMarketplace_AlreadyListed(nftAddress, tokenId);
		_;
	}

	modifier isListed(address nftAddress, uint256 tokenId) {
		Listing memory listing = s_listings[nftAddress][tokenId];
		if (listing.price <= 0)
			revert NFTMarketplace_NotListed(nftAddress, tokenId);
		_;
	}

	modifier isOwner(
		address nftAddress,
		uint256 tokenId,
		address spender
	) {
		address owner;
		IERC721 nft = IERC721(nftAddress);
		owner = nft.ownerOf(tokenId);
		if (spender != owner) revert NFTMarketplace_NotOwner();
		_;
	}

	/////////////////

	function listItem(
		address nftAddress,
		uint256 tokenId,
		uint256 price
	)
		external
		notListed(nftAddress, tokenId, msg.sender)
		isOwner(nftAddress, tokenId, msg.sender)
	{
		if (price <= 0) revert NFTMarketplace_PriceMustBeAboveZero();
		IERC721 nft = IERC721(nftAddress);
		if (nft.getApproved(tokenId) != address(this))
			revert NFTMarketplace_NotApprovedForMarketplace();
		s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
		emit ItemListed(msg.sender, nftAddress, tokenId, price);
	}

	function buyItem(address nftAddress, uint256 tokenId)
		external
		payable
		isListed(nftAddress, tokenId)
		nonReentrant
	{
		Listing memory listedItem = s_listings[nftAddress][tokenId];
		if (msg.value < listedItem.price) {
			revert NFTMarketplace_PriceNotMet(
				nftAddress,
				tokenId,
				listedItem.price
			);
		}
		s_proceeds[listedItem.seller] =
			s_proceeds[listedItem.seller] +
			msg.value;
		// We don't just send the seller the money
		delete (s_listings[nftAddress][tokenId]);
		IERC721(nftAddress).safeTransferFrom(
			listedItem.seller,
			msg.sender,
			tokenId
		);
		emit itemBought(msg.sender, nftAddress, tokenId, listedItem.price);
	}

	function cancelListing(address nftAddress, uint256 tokenId)
		external
		isOwner(nftAddress, tokenId, msg.sender)
		isListed(nftAddress, tokenId)
	{
		delete (s_listings[nftAddress][tokenId]);
		emit ItemCanceled(msg.sender, nftAddress, tokenId);
	}

	function updateListing(
		address nftAddress,
		uint256 tokenId,
		uint256 newPrice
	)
		external
		isOwner(nftAddress, tokenId, msg.sender)
		isListed(nftAddress, tokenId)
	{
		s_listings[nftAddress][tokenId].price = newPrice;
		emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
	}

	function withdrawProceeds() external {
		uint256 proceeds = s_proceeds[msg.sender];
		if (proceeds <= 0) {
			revert NFTMarketplace_NoProceeds();
		}
		s_proceeds[msg.sender] = 0;
		(bool success, ) = payable(msg.sender).call{value: proceeds}('');
		if (!success) {
			revert NFTMarketplace__TransferFailed();
		}
	}

	//////////////////
	///// Getters ////
	//////////////////
	function getListing(address nftAddress, uint256 tokenId)
		external
		view
		returns (Listing memory)
	{
		return s_listings[nftAddress][tokenId];
	}

	function getProceeds(address seller) external view returns (uint256) {
		return s_proceeds[seller];
	}
}
