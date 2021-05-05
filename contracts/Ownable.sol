// contracts/Ownable.sol
pragma solidity 0.5.16;

contract Ownable {
  address public owner;

  modifier onlyOwner() {
    require(owner == msg.sender);
    _;
  }

  constructor() public {
    owner = msg.sender;
  }
}
