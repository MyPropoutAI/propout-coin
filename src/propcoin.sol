// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PropCoin is ERC20, Ownable {

    // Initial supply of tokens
    uint256 private initialSupply = 1000000 * 10 ** decimals();

    // Mapping to freeze accounts
    mapping(address => bool) private frozenAccounts;

    // Event to notify when tokens are frozen
    event AccountFrozen(address indexed account, bool isFrozen);

    // Event to notify when tokens are airdropped
    event Airdrop(address indexed recipient, uint256 amount);

    // Event to notify token lock
    event TokensLocked(address indexed account, uint256 amount, uint256 unlockTime);

    // Event to notify token unlock
    event TokensUnlocked(address indexed account, uint256 amount);

    // Token lock data
    struct Lock {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => Lock[]) private locks;

    constructor() ERC20("PropCoin", "PROP") {
        // Mint initial supply to the owner of the contract
        _mint(msg.sender, initialSupply);
    }

    // Function to mint new tokens, only callable by the owner
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Function to burn tokens from the caller's account
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    // Function to airdrop tokens to multiple addresses
    function airdrop(address[] memory recipients, uint256 amount) external onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amount);
            emit Airdrop(recipients[i], amount);
        }
    }

    // Function to freeze or unfreeze an account
    function setFreezeAccount(address account, bool freeze) external onlyOwner {
        frozenAccounts[account] = freeze;
        emit AccountFrozen(account, freeze);
    }

    // Override transfer function to prevent transfer from/to frozen accounts
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        require(!frozenAccounts[from], "ERC20: sender account is frozen");
        require(!frozenAccounts[to], "ERC20: recipient account is frozen");
        super._beforeTokenTransfer(from, to, amount);
    }

    // Function to lock tokens with a specific unlock time
    function lockTokens(address account, uint256 amount, uint256 duration) external onlyOwner {
        require(balanceOf(account) >= amount, "ERC20: insufficient balance to lock");

        // Lock the tokens
        uint256 unlockTime = block.timestamp + duration;
        locks[account].push(Lock(amount, unlockTime));

        // Emit event
        emit TokensLocked(account, amount, unlockTime);
    }

    // Function to unlock tokens
    function unlockTokens() external {
        uint256 unlockedAmount = 0;
        uint256 i = 0;
        
        // Iterate over all lock entries
        while (i < locks[msg.sender].length) {
            if (locks[msg.sender][i].unlockTime <= block.timestamp) {
                unlockedAmount += locks[msg.sender][i].amount;
                // Remove unlocked entry
                locks[msg.sender][i] = locks[msg.sender][locks[msg.sender].length - 1];
                locks[msg.sender].pop();
            } else {
                i++;
            }
        }

        require(unlockedAmount > 0, "ERC20: no tokens to unlock");

        // Transfer unlocked tokens back to the user
        _transfer(address(this), msg.sender, unlockedAmount);

        // Emit event
        emit TokensUnlocked(msg.sender, unlockedAmount);
    }

    // Override transfer function to lock tokens if they are transferred to the contract address
    function _transfer(address from, address to, uint256 amount) internal override {
        super._transfer(from, to, amount);
        if (to == address(this)) {
            // Automatically lock tokens when transferred to the contract
            lockTokens(from, amount, 30 days); // Example lock duration of 30 days
        }
    }
}