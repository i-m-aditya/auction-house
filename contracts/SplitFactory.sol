pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Splitter.sol";

contract SplitFactory {
    
    address public immutable splitter;
    address public immutable auctionHouse;
    
    event SplitterCreated(address splitter, bytes32 merkelRoot, address _auctionCurrency, address _owner, address auctionHouse);
    
    constructor (address _splitter, address _token) {
        splitter = _splitter;
        auctionHouse = auctionHouse;
    }
    
    /**
   * @notice Creates a new splitter contract
   * @param _merkleRoot Merkle root for storing indexes and percentages of the partners
   * @param _auctionCurrency Token address used in the auction
   * @param _owner Owner of the splitter contract with authorization to call auction-related methods
   * @return Address of the new Splitter contract
   */
    function createSplitter(bytes32 _merkleRoot, address _auctionCurrency, address _owner) external returns (address) {
        address _splitter = splitter.cloneDeterministic(_merkleRoot); // salt is merkelRoot, no two exact same splitters could exist
        Splitter(_splitter).initialize(_merkleRoot, _auctionCurrency, _owner, auctionHouse);
        
        
        // Emiting event after successful creation of splitter
        emit SplitterCreated(_splitter, _merkleRoot, _auctionCurrency, _owner, auctionHouse);
        
        return _splitter;
    }

    /**
    * @notice _merkleRoot of the splitter contract
    * @return the address of that splitter contract
    */
   function getSplitterAddress(bytes32 _merkleRoot) external view returns (address) {
    return implementation.predictDeterministicAddress(_merkleRoot);
  }
}