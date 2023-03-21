pragma solidity ^ 0.8.9;
import "@openzeppelin/contracts/utils/Strings.sol";

contract MiningPool {

    bool private isPaid = false;
    uint32 private id = 0;
    uint32 private shares;
    uint32 private difficulty;
    uint32 private version;
    uint32 private reward;
    uint32 private threshhold;
    uint256 private previousHash;
    bytes[] private transactionsArray;
    address private owner;
    address[] private members;
    address[] private memberShares;
    mapping(uint => address) private addressToOwner; 

    constructor() {
        owner = msg.sender;
    }

/**
* Allows only the contract owner to call a function.
*/
    modifier onlyOwner() {
        require(owner == msg.sender);
        _;
    }

/**
* Allows only a specific member to call a function.
*/
    modifier onlyOwnerOf(uint _memberId) {
        require(msg.sender == addressToOwner[_memberId]);
        _;
    }

/**
* Join mining pool and get a specific id.
*/
    function _joinPool() public {
        members.push(msg.sender) ;
        addressToOwner[getMemberId()] = msg.sender;
		setMemberId();
    }

/**
* Sets member id.
*/
    function setMemberId () private returns(uint32){
		id = id + 1;
        return id ;
    } 

/**
* Returns member id.
*/ 
    function getMemberId() public view returns(uint32){
        return id;
    }

/**
* Pool manager defines the previous block.
*/
    function previousBlock (uint256 _previousHash) public onlyOwner returns(uint256){
        previousHash = _previousHash;
        return previousHash;
    }

/**
* Pool manager defines block difficulty.
*/
    function blockDifficulty (uint32 _difficulty) public onlyOwner returns(uint32){
        difficulty = _difficulty;
        return difficulty;
    }

/**
* Pool manager defines the threshold up to which the first N shares are rewarded.
*/
    function shareThreshold (uint32 _threshold) public onlyOwner returns(uint32){
        threshhold = _threshold;
        return threshhold;
    }

/**
* Pool manager defines the version.
*/
    function blockVersion (uint32 _version) public onlyOwner returns(uint32){
        version = _version;
        return version;
    }

/**
* Pool manager defines the reward as the amount of money received from mining a block.
*/
    function setReward (uint32 _reward) public onlyOwner returns(uint32){
        reward = _reward;
        return reward;
    }

/**
* Pool manager defines the array of transactions that members will use to mine the block.
*/
    function transactionsOfCBlock (bytes[] memory _transactionsArray) public onlyOwner returns(bytes[] memory){
        transactionsArray = _transactionsArray;
        return transactionsArray;
    }

/**
* Pool manager defines the number of shares (i.e. first N near valid blocks which
* will be rewarded.
*/
    function defineNumberOfShares (uint32 _shares) public onlyOwner returns (uint32){
        shares = _shares;
        return shares;
    }

/**
* Returns number of shares defined by the pool manager.
*/
    function getShares() public view returns (uint32){
        return shares;
    }

/**
* Returns the threshold up to which the first N shares are rewarded 
* as defined by the pool manager.
*/
    function getThreshold() public view returns (uint32){
        return threshhold;
    }

/**
* Matches transactions to integers. Transactions are large, so it is better 
* for each member to provide the sequence of integers that correspond to 
* the transactions.
*/   
    function matchTransactionsToNumbers () public view returns (uint32[] memory){
        uint32[] memory transactionNumber;
        for (uint32 i=0; i<transactionsArray.length; i++) {
            transactionNumber[i] = i;
        }
        return transactionNumber;
    }

/**
* A miner can call this function when they find the next block. Given the merkle tree
* root, the timestamp and the nonce, the concatenated string of the block header is
* calculated. Double hash function SHA-256 is performed on the concatenated value 
* and finally the function checks whether the hash is valid and the member belongs 
* to the pool. Money received from the mining process are sent to the contract.
*/   
    function validateNextBlock(uint256 _merkleRoot, uint32 _timestamp, uint32 _nonce) public {
        string memory v = Strings.toString(version);
        string memory ph = Strings.toString(previousHash);
        string memory mr = Strings.toString(_merkleRoot);
        string memory t = Strings.toString(_timestamp);
        string memory d = Strings.toString(difficulty);
        string memory n = Strings.toString(_nonce);
        string memory concat = string(abi.encodePacked(v,' ',ph,' ',mr,' ',t,' ',d,' ',n));
        uint headerHash = uint(sha256(abi.encodePacked(concat)));
        uint doubleHeaderHash = uint(sha256(abi.encodePacked(headerHash)));
        require(doubleHeaderHash < difficulty && isMember(msg.sender));
        sendRewardToContract();
    }

/**
* Checks whether a miner belongs in the mining pool.
*/   
    function isMember (address _memberAddress) public view returns(bool){
        for (uint32 i=0; i < getMemberId(); i++) {
            if (addressToOwner[i] == _memberAddress)
                return true;
        }
        return false;
    }

/**
* Money received from mining a block are stored in the contract's balance.
*/   
    function sendRewardToContract () public payable {
        require (isMember(msg.sender) && (msg.value == reward));
        getPaid (msg.sender);
    }

/**
* Miner who found next block receives half of the amount of money.
*/   
    function getPaid(address _address) private{
        uint balance = getBalance();
        address payable sender = payable (_address);
        sender.transfer(balance/2);
        isPaid = true;
    }

/**
* Returns contract's balance.
*/   
    function getBalance () public view returns(uint){
        return address(this).balance;
    }

/**
* A miner can call this function when they find the near valid blocks. Given the 
* merkle tree root, the timestamp and the nonce, the concatenated string of the 
* block header is calculated. Double hash function SHA-256 is performed on the 
* concatenated value and finally the function checks whether the hash is valid 
* (i.e. above difficulty but below the threshold), the member belongs to the pool
* and has not been paid already. N shares are rewarded.
*/   
    function validateShares (uint256 _merkleRoot, uint32 _timestamp, uint32 _nonce) public {
        uint32 count = 0;
        string memory v = Strings.toString(version);
        string memory ph = Strings.toString(previousHash);
        string memory mr = Strings.toString(_merkleRoot);
        string memory t = Strings.toString(_timestamp);
        string memory d = Strings.toString(difficulty);
        string memory n = Strings.toString(_nonce);
        string memory concat = string(abi.encodePacked(v,' ',ph,' ',mr,' ',t,' ',d,' ',n));
        uint headerHash = uint(sha256(abi.encodePacked(concat)));
        uint doubleHeaderHash = uint(sha256(abi.encodePacked(headerHash)));
        require(doubleHeaderHash > difficulty && isMember(msg.sender) && doubleHeaderHash < getThreshold() && isMemberPaid(msg.sender) == false);
        memberShares[count] = msg.sender;
        count = count + 1 ;
        address payable sender = payable (msg.sender);
        rewardShares(sender,count);
    }

/**
* After the payment of the miner who found the next block occurs, the first N 
* near valid blocks are rewarded with half of the amount of money divided by 
* the number of shares.
*/   
    function rewardShares (address payable _address, uint32 _counter) private {
        uint balance = getBalance();
        require (_counter < getShares() && isPaid == true);
        _address.transfer(balance/getShares());
    }

/**
* Checks whether a member has been already paid.
*/   
    function isMemberPaid (address _memberAddress) public view returns(bool){
        for (uint32 i=0; i < memberShares.length; i++) {
            if (memberShares[i] == _memberAddress)
                return true;
        }
        return false;
    }    
}