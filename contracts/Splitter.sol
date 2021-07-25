// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import {SafeERC20, SafeMath} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract Splitter{
    
    // Libraries
    using SafeERC20 for IERC20;
    
    // Currency used in auction
    address public auctionCurrency;

    // Merkle root used to verify fund claims by users
    bytes32 public merkleRoot;
    address public owner;
    
    // total amount generated after successful auction
    uint256 public auctionGeneratedFund;

    // @notice Address of zora auction house
    IAuctionHouse auctionHouse;

    // @notice Auction Id created by this contract
    uint256 public auctionId;
    
    
    /*
    *@notice Will be using array of claims for batch claims
    */
    struct Claim {
        uint256 index;
        address account;
        uint256 percent;
        bytes32[] merkleProof;
    }
    
    
      /**
       * @notice Initializing the Splitter
       * @dev Used in place of the constructor, since constructors do not run during EIP-1167 proxy creation
       * @param _merkleRoot Merkle root for storing indexes and percentages of the claimers
       * @param _auctionCurrency Token address used in the auction
       * @param _owner Owner of the splitter contract with authorization to call auction-related methods
       * @param _auctionHouse Address of the auction house
       */
    function initialize(address _merkleRoot, address _auctionCurrency, address _owner,address _auctionHouse) {
        auctionCurrency = _auctionCurrency;
        merkleRoot = _merkleRoot;
        owner = _owner;
        auctionHouse = IAuctionHouse(auctionHouse);
    }
    
    // Plain ETH transfers.
    receive() external payable {
        
    }
    
    
    
    // This is a packed array of booleans.
    // Using this we can make sure to put an upper bound on the maximum number of keys in map
    // For example, suppose we have to split a revenue with 65536 accounts, number of keys used in that case will be 65536 / 256 = 256.
    mapping(uint256 => uint256) private claimedBitMap;
    
    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 index, address account, uint256 amount);
    
    // --- Modifiers ---
    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    uint256 public constant PERCENTAGE_SCALE = 10e5;
    

    /**
    *@dev with the help of this we can put an upper bound on the maximum number of keys in map, therefore less storage and less gas fees
    */
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        // Checking whether claimedBitIndex is set in claimedWordIndex, if yes then the user has already claimed
        return (claimedWord & mask) == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }
    // ------- Claim Funds --------
    /**
     *@notice User can claim their funds
     * @param _index Index of the User in this auction, for ex: if there are 100 users, then it ranges from [0, 99] 
     * @param _account Address of the user claiming the fund
     * @param _percent Percentage of the fund this user is eligible
     * @param _merkleProof Proof that the account is eligible for `_percent` of auctionGeneratedFund
     * 
    */
    function claim(uint256 _index, address _account, uint256 _percent, bytes32[] calldata merkleProof) external {
        require(!isClaimed(index), 'Splitter: Already claimed.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, _percent));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'Invalid Proof');

        // Mark it claimed and send the token.
        _setClaimed(index);
        
        
        require(IERC20(auctionCurrency).safeTransfer(_account, scaleAmountByPercentage(auctionGeneratedFund, _percent)), "Failed to transfer amount to given address");
        
        // require(IERC20(token).transfer(account, amount), 'Splitter: Transfer failed.');

        emit Claimed(index, account, amount);
    }


    /**
    * @notice Enabling batch claiming of funds
    * @dev Taking array of claims as an input
    */
    function batchClaims(Claim[] claims) external {
        for(uint256 i=0; i<claims.length; i++) {
            claim(claims[i].index, claims[i].account, claims[i].percent, claims[i].merkleProof);
        }
    }
    
    function scaleAmountByPercentage(uint256 amount, uint256 scaledPercent)
        public
        pure
        returns (uint256 scaledAmount)
    {
        /*
            Example:
                If there is 100 ETH in the account, and someone has 
                an allocation of 2%, we call this with 100 as the amount, and 200
                as the scaled percent.

                To find out the amount we use, for example: (100 * 200000) / (100 * 100000)
                which returns 2 -- i.e. 2% of the 100 ETH balance.
         */
        scaledAmount = (amount * scaledPercent) / (100 * PERCENTAGE_SCALE);
    }
    
    
  // --- Auction management ---
  /**
   * @notice Create a new auction from this Splitter. To create an auction, the Splitter must own the NFT
   * @dev See AuctionHouse documentation for details on each input
   * @dev `auctionCurrency` is not an input as it was initialzed during splitter initiallization
   */
  function createAuction(
    uint256 _tokenId,
    address _tokenContract,
    uint256 _duration,
    uint256 _reservePrice,
    address payable _curator,
    uint8 _curatorFeePercentages
  ) external onlyOwner returns (uint256) {
    require(auctionId == 0, "An auction has already been created");
    IERC721(_tokenContract).approve(address(auctionHouse), _tokenId);
    auctionId = auctionHouse.createAuction(_tokenId, _tokenContract, _duration, _reservePrice, _curator, _curatorFeePercentages, auctionCurrency);
    return auctionId;
  }

  /**
   * @notice Approve an auction, opening up the auction for bids.
   * @dev Only callable by the curator. Cannot be called if the auction has already started.
   */
  function setAuctionApproval(bool _approved) external onlyOwner {
    auctionHouse.setAuctionApproval(auctionId, _approved);
  }

  /**
   * @notice Sets the reserve price of the auction
   * @dev Only callable by the curator or the token owner
   */
  function setAuctionReservePrice(uint256 _reservePrice) external onlyOwner {
    auctionHouse.setAuctionReservePrice(auctionId, _reservePrice);
  }

  /**
   * @notice Calls the AuctionHouse to end the auction, and saves the fund generated from the auction
   */
  function endAuction() public {
    // End auction, which transfers auction generated fund to this contract
    auctionHouse.endAuction(auctionId);

    // Save off that amount as the amount to split
    auctionGeneratedFund = IERC20(auctionCurrency).balanceOf(address(this));
  }

  

  /**
   * @notice Cancel an auction.
   * @dev Only callable by the curator or the token owner
   */
  function cancelAuction() external onlyOwner {
    require(auctionId > 0, "An auction has not been created");
    auctionHouse.cancelAuction(auctionId);
  }
    
}