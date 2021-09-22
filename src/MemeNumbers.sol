// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

library Errors {
    string constant AlreadyMinted = "already minted";
    string constant UnderPriced = "current price is higher than msg.value";
    string constant NotForSale = "number is not for sale in this batch";
    string constant MustOwnNum = "must own number to operate on it";
    string constant InvalidOp = "invalid op";
    string constant DoesNotExist = "does not exist";
}

library Util {
    function cmp(string calldata a, string calldata b) pure public returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}

contract MemeNumbers is ERC721, Ownable {
    uint256 public constant AUCTION_START_PRICE = 5 ether;
    uint256 public constant AUCTION_DURATION = 1 hours;
    uint256 public constant BATCH_SIZE = 7;

    uint256 public auctionStarted;
    uint256[BATCH_SIZE] private forSale;

    constructor() ERC721("MemeNumbers", "MEMENUM") {
        _refresh();
    }

    // Internal helpers:

    function _getEntropy() view internal returns(uint256) {
        // FIXME: Are we happy with this source of entropy? Miners can
        // influence this, but they're still required to compete in the dutch
        // auction. Perhaps we should start the dutch auction on a very high
        // curve to price out MEV bundles.

        // Alternative option is simply:
        //   return return uint256(blockhash(block.number));

        // Borrowed from: https://github.com/1001-digital/erc721-extensions/blob/f5c983bac8989bc5ebf9b34c03f28e438da9a7b3/contracts/RandomlyAssigned.sol#L27
        return uint256(keccak256(
            abi.encodePacked(
                msg.sender,
                block.coinbase,
                block.difficulty,
                block.gaslimit,
                block.timestamp,
                blockhash(block.number))));
    }

    /**
     * @dev Generate a fresh sequence available for sale based on the current block state.
     */
    function _refresh() internal {
        auctionStarted = block.timestamp;

        uint256 entropy = _getEntropy();

        // Slice it up with fibonacci bit masks: 5, 8, 13, 21, 34, 55, 89
        // Eligibility is confirmed during sale/view
        forSale[0] = (entropy >> 0) ^ (2 ** 5 - 1);
        forSale[1] = (entropy >> 5) ^ (2 ** 8 - 1);
        forSale[2] = (entropy >> 8) ^ (2 ** 13 - 1);
        forSale[3] = (entropy >> 13) ^ (2 ** 21 - 1);
        forSale[4] = (entropy >> 21) ^ (2 ** 34 - 1);
        forSale[5] = (entropy >> 34) ^ (2 ** 55 - 1);
        forSale[6] = (entropy >> 55) ^ (2 ** 89 - 1);
    }


    // Public views:

    function currentPrice() view public returns(uint256) {
        // Linear price reduction from AUCTION_START_PRICE to 0
        uint256 endTime = (auctionStarted + AUCTION_DURATION);
        if (block.timestamp >= endTime) {
            return 0;
        }
        return AUCTION_START_PRICE * ((endTime - block.timestamp) / AUCTION_DURATION);
    }

    function isForSale(uint256 num) view public returns (bool) {
        for (uint256 i=0; i<forSale.length; i++) {
            if (forSale[i] == num) return true;
        }
        return false;
    }

    function getForSale() view public returns (uint256[] memory) {
        uint256[] memory r = new uint256[](BATCH_SIZE);
        uint256 count = 0;
        for (uint256 i=0; i<forSale.length; i++) {
            if (_exists(forSale[i])) continue;
            r[count] = forSale[i];
            count += 1;
        }
        return r;
    }

    /**
     * @dev Apply a mathematical operation on two numbers, returning the
     *   resulting number. Treat this as a read-only preview of `burn`.
     * @param num1 Number to burn, must own
     * @param op Operation to burn num1 and num2 with, one of: add, sub, mul, div
     * @param num2 Number to burn, must own
     */
    function operate(uint256 num1, string calldata op, uint256 num2) public pure returns (uint256) {
        if (Util.cmp(op, "add")) {
            return num1 + num2;
        }
        if (Util.cmp(op, "sub")) {
            return num1 - num2;
        }
        if (Util.cmp(op, "mul")) {
            return num1 * num2;
        }
        if (Util.cmp(op, "div")) {
            return num1 / num2;
        }
        revert(Errors.InvalidOp);
    }


    // Main interface:

    /**
     * @dev Mint one of the numbers that are currently for sale at the current dutch auction price.
     * @param to Address to mint the number into.
     * @param num Number to mint, must be in the current for-sale sequence.
     */
    function mint(address to, uint256 num) external payable {
        require(!_exists(num), Errors.AlreadyMinted);
        require(currentPrice() <= msg.value, Errors.UnderPriced);
        require(isForSale(num), Errors.NotForSale);

        // XXX: Refund difference of currentPrice vs msg.value to allow overbidding

        _mint(to, num);
    }

    /**
     * @dev Burn two numbers together using a mathematical operation, producing
     *   a new number if it is not already taken. No minting fee required.
     * @param to Address to mint the resulting number into.
     * @param num1 Number to burn, must own
     * @param op Operation to burn num1 and num2 with, one of: add, sub, mul, div
     * @param num2 Number to burn, must own
     */
    function burn(address to, uint256 num1, string calldata op, uint256 num2) external {
        require(ownerOf(num1) == _msgSender(), Errors.MustOwnNum);
        require(ownerOf(num2) == _msgSender(), Errors.MustOwnNum);

        uint256 num = operate(num1, op, num2);
        require(!_exists(num), Errors.AlreadyMinted);

        _mint(to, num);
    }


    // Renderer:

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), Errors.DoesNotExist);
        // XXX: Implement a renderer, probably as a separate upgradeable thing
        return "data:application/json;{}";
    }


    // onlyOwner admin functions:

    function withdraw(address payable to) external onlyOwner {
        to.transfer(address(this).balance);
    }

}
