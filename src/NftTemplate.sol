// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./NftTemplateRenderer.sol";

library Errors {
    string constant AlreadyMinted = "already minted";
    string constant UnderPriced = "current price is higher than msg.value";
    string constant NotForSale = "number is not for sale in this batch";
    string constant MustOwnNum = "must own number to operate on it";
    string constant NoSelfBurn = "burn numbers must be different";
    string constant InvalidOp = "invalid op";
    string constant DoesNotExist = "does not exist";
    string constant RendererUpgradeDisabled = "renderer upgrade disabled";
}

contract NftTemplate is ERC721, Ownable {
    uint256 public constant AUCTION_START_PRICE = 1 ether;
    uint256 public constant AUCTION_DURATION = 1 hours;

    uint256 public auctionStarted;

    mapping(uint256 => bool) viaBurn; // Numbers that were created via burn

    /// disableRenderUpgrade is whether we can still upgrade the tokenURI renderer.
    /// Once it is set it cannot be unset.
    bool disableRenderUpgrade = false;
    ITokenRenderer public renderer;

    /// @notice Emitted when the auction batch is refreshed.
    event Refresh(); // TODO: Do we want to include any fields?

    constructor(address _renderer) ERC721("NftTemplate", "TEMPLATE") {
        renderer = ITokenRenderer(_renderer);
        _refresh();
    }

    /**
     * @dev Generate a fresh sequence available for sale based on the current block state.
     */
    function _refresh() internal {
        auctionStarted = block.timestamp;
        emit Refresh();
    }

    // Public views:

    /// @notice The current price of the dutch auction. Winning bids above this price will return the difference.
    function currentPrice() public view returns (uint256) {
        return 0;
    }

    /// @notice Return whether a number is for sale and eligible
    function isForSale(uint256 num) public view returns (bool) {
        return !_exists(num);
    }

    /// @notice Returns whether num was minted by burning, or if it is an original from auction.
    function isMintedByBurn(uint256 num) external view returns (bool) {
        return viaBurn[num];
    }

    // Main interface:

    /**
     * @notice Mint one of the numbers that are currently for sale at the current dutch auction price.
     * @param to Address to mint the number into.
     * @param num Number to mint, must be in the current for-sale sequence.
     *
     * Emits a {Refresh} event.
     */
    function mint(address to, uint256 num) external payable {
        uint256 price = currentPrice();
        require(price <= msg.value, Errors.UnderPriced);
        require(isForSale(num), Errors.NotForSale);

        _mint(to, num);
        _refresh();

        if (msg.value > price) {
            // Refund difference of currentPrice vs msg.value to allow overbidding
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    /**
     * @notice Mint all of the eligible numbers for sale, uses more gas than mint but you get more numbers.
     * @param to Address to mint the numbers into.
     *
     * Emits a {Refresh} event.
     */
    function mintAll(address to) external payable {
        uint256 price = currentPrice();
        require(price <= msg.value, Errors.UnderPriced);

        for (uint256 i = 0; i < forSale.length; i++) {
            if (_exists(forSale[i])) continue;
            _mint(to, forSale[i]);
        }

        _refresh();

        if (msg.value > price) {
            // Refund difference of currentPrice vs msg.value to allow overbidding
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    /**
     * @notice Refresh the auction without minting once the auction price is 0. More gas efficient than doing a free mint.
     *
     * Emits a {Refresh} event.
     */
    function refresh() external {
        require(currentPrice() == 0, Errors.UnderPriced);
        _refresh();
    }

    /**
     * @notice Burn two numbers together using a mathematical operation, producing
     *   a new number if it is not already taken. No minting fee required.
     * @param to Address to mint the resulting number into.
     * @param num1 Number to burn, must own
     * @param op Operation to burn num1 and num2 with, one of: add, sub, mul, div
     * @param num2 Number to burn, must own
     */
    function burn(
        address to,
        uint256 num1,
        string calldata op,
        uint256 num2
    ) external {
        require(num1 != num2, Errors.NoSelfBurn);
        require(ownerOf(num1) == _msgSender(), Errors.MustOwnNum);
        require(ownerOf(num2) == _msgSender(), Errors.MustOwnNum);

        uint256 num = operate(num1, op, num2);
        require(!_exists(num), Errors.AlreadyMinted);

        _mint(to, num);
        viaBurn[num] = true;

        _burn(num1);
        _burn(num2);
        delete viaBurn[num1];
        delete viaBurn[num2];
    }

    // Renderer:

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), Errors.DoesNotExist);
        return renderer.tokenURI(INftTemplate(address(this)), tokenId);
    }

    // onlyOwner admin functions:

    /// @notice Withdraw contract balance.
    function adminWithdraw(address payable to) external onlyOwner {
        to.transfer(address(this).balance);
    }

    /// @notice Change the tokenURI renderer.
    /// @param _renderer Address of ITokenRenderer.
    function adminSetRenderer(address _renderer) external onlyOwner {
        require(disableRenderUpgrade == false, Errors.RendererUpgradeDisabled);
        renderer = ITokenRenderer(_renderer);
    }

    /// @notice Disable upgrading the renderer. Once it is disabled, it cannot be enabled again.
    function adminDisableRenderUpgrade() external onlyOwner {
        disableRenderUpgrade = true;
    }
}
