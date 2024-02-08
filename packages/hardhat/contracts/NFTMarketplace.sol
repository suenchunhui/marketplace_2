// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NFTMarketplace is IERC721Receiver {
    using EnumerableSet for EnumerableSet.UintSet;

    address private owner;
    uint private feePercentage;
    uint private listingIdCounter;
    
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }
    
    mapping(uint => Listing) private listings;
    mapping(address => EnumerableSet.UintSet) private sellerListings;
    
    event ListingCreated(uint indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event ListingUpdated(uint indexed listingId, uint256 newPrice);
    event ListingRemoved(uint indexed listingId);
    event NFTSold(uint indexed listingId, address indexed seller, address indexed buyer, uint256 price);
    event FeePercentageUpdated(uint newFeePercentage);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        feePercentage = 0; // set default fee percentage as 0
        listingIdCounter = 1; // initialize listingIdCounter with 1
    }
    
    // Function to create a new listing for an NFT
    function createListing(address _nftContract, uint256 _tokenId, uint256 _price) external {
        require(_price > 0, "Price must be greater than 0");
        
        IERC721 nftContract = IERC721(_nftContract);
        require(nftContract.ownerOf(_tokenId) == msg.sender, "You do not own this NFT");
        require(nftContract.getApproved(_tokenId) == address(this), "Contract is not approved to transfer NFT");

        Listing memory newListing = Listing({
            seller: msg.sender,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true
        });

        listings[listingIdCounter] = newListing;
        sellerListings[msg.sender].add(listingIdCounter);
        
        emit ListingCreated(listingIdCounter, msg.sender, _nftContract, _tokenId, _price);
        
        listingIdCounter++;
    }
    
    // Function to update the price of a listing
    function updateListingPrice(uint _listingId, uint256 _newPrice) external {
        require(listings[_listingId].seller == msg.sender, "You are not the seller of this listing");
        require(listings[_listingId].isActive, "Listing is not active");
        
        listings[_listingId].price = _newPrice;
        
        emit ListingUpdated(_listingId, _newPrice);
    }
    
    // Function to remove a listing
    function removeListing(uint _listingId) external {
        require(listings[_listingId].seller == msg.sender, "You are not the seller of this listing");
        require(listings[_listingId].isActive, "Listing is not active");
        
        delete listings[_listingId];
        sellerListings[msg.sender].remove(_listingId);
        
        emit ListingRemoved(_listingId);
    }
    
    // Function to buy an NFT from a listing
    function buyNFT(uint _listingId) external payable {
        require(listings[_listingId].isActive, "Listing is not active");
        require(msg.value >= listings[_listingId].price, "Insufficient payment amount");

        address seller = listings[_listingId].seller;
        uint256 price = listings[_listingId].price;
        address nftContract = listings[_listingId].nftContract;
        uint256 tokenId = listings[_listingId].tokenId;

        IERC721(nftContract).transferFrom(seller, msg.sender, tokenId);
        
        if(feePercentage > 0) {
            uint256 feeAmount = (price * feePercentage) / 100;
            payable(owner).transfer(feeAmount);
            payable(seller).transfer(price - feeAmount);
        } else {
            payable(seller).transfer(price);
        }
        
        delete listings[_listingId];
        sellerListings[seller].remove(_listingId);
        
        emit NFTSold(_listingId, seller, msg.sender, price);
    }
    
    // Function to set the fee percentage
    function setFeePercentage(uint _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 100, "Fee percentage must be between 0 and 100");
        feePercentage = _newFeePercentage;
        
        emit FeePercentageUpdated(_newFeePercentage);
    }
    
    // Function to get the total number of listings
    function getTotalListings() public view returns (uint) {
        return listingIdCounter - 1;
    }
    
    // Function to get the listing details by listing ID
    function getListing(uint _listingId) public view returns (Listing memory) {
        return listings[_listingId];
    }
    
    // Function to get the list of listings by seller address
    function getSellerListings(address _seller) public view returns (uint[] memory) {
        uint[] memory result = new uint[](sellerListings[_seller].length());
        
        for(uint i = 0; i < sellerListings[_seller].length(); i++) {
            result[i] = sellerListings[_seller].at(i);
        }
        
        return result;
    }
    
    // Function to receive NFTs
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}