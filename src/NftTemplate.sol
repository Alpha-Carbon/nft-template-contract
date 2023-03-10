// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

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

contract NftTemplate is ERC721Enumerable, Ownable {

    /// disableRenderUpgrade is whether we can still upgrade the tokenURI renderer.
    /// Once it is set it cannot be unset.
    bool disableRenderUpgrade = false;
    ITokenRenderer public renderer;

    /// @notice Emitted when the auction batch is refreshed.
    event Refresh(); // TODO: Do we want to include any fields?

    constructor(address _renderer) ERC721("NftTemplate", "TEMPLATE") {
        renderer = ITokenRenderer(_renderer);
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

    // Main interface:

    /**
     * @notice Mint one of the numbers that are currently for sale at the current dutch auction price.
     * @param to Address to mint the number into.
     *
     * Emits a {Refresh} event.
     */
    function mint(address to) external payable {
        uint256 price = currentPrice();
        uint256 tokenId = totalSupply();

        require(price <= msg.value, Errors.UnderPriced);
        require(isForSale(tokenId), Errors.NotForSale);
        _mint(to, tokenId);

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
    function mintBatch(address to, uint256 amount) external payable {
        uint256 price = currentPrice();
        require(price <= msg.value, Errors.UnderPriced);

        uint256 current = totalSupply();
        for (uint256 i = current; i < current + amount; i++) {
            if (_exists(i)) continue;
            _mint(to, i);
        }

        if (msg.value > price) {
            // Refund difference of currentPrice vs msg.value to allow overbidding
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    /**
     * @notice Burn two numbers together using a mathematical operation, producing
     *   a new number if it is not already taken. No minting fee required.
     * @param tokenId Number to burn, must own
     */
    function burn(
        address to,
        uint256 tokenId
    ) external {
        require(ownerOf(tokenId) == _msgSender(), Errors.MustOwnNum);
        _burn(tokenId);
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
