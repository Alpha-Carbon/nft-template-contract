//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";

import "base64/base64.sol";

interface INftTemplate {}

interface ITokenRenderer {
    function tokenURI(
        INftTemplate instance,
        uint256 tokenId
    ) external view returns (string memory);
}

contract NftTemplateRenderer is ITokenRenderer {
    using Strings for uint;

    enum Shape {Circle, Cross, Square, Triangle}

    function _getShape(uint256 tokenId) internal pure returns (Shape){
        // remainder:
        // 0 => Circle
        // 1 => Cross
        // 2 => Square
        // 3 => Triangle
        return Shape(uint8(tokenId % 4));
    }

    function _displayShape(Shape shape) internal pure returns (string memory){
        if(shape == Shape.Circle){
            return "Circle";
        } else if(shape == Shape.Cross){
            return "Cross";
        } else if(shape == Shape.Square){
            return "Square";
        } else {
            return "Triangle";
        }
    }

    function _getColor(uint256 tokenId) internal pure returns (string memory){
      // map u256 space to hex color space (#FFFFFF) which is 24 bits ,
      // right shift 256 - 24 = 232 bits
      uint256 color = uint256(keccak256(abi.encodePacked(tokenId)) >> 232);

      return toHexString(color);
      
    }

    function toHexDigit(uint8 d) pure internal returns (bytes1) {
        if (0 <= d && d <= 9) {
            return bytes1(uint8(bytes1('0')) + d);
        } else if (10 <= uint8(d) && uint8(d) <= 15) {
            return bytes1(uint8(bytes1('a')) + d - 10);
        }
        // revert("Invalid hex digit");
        revert();
    }

    function toHexString(uint a) public pure returns (string memory) {
        // if hex length < 6 digit after right shifting, padding 0 until 6 digit to fulfill hex color code
        uint count = 6;
        uint b = a;
        while (b != 0) {
            b /= 16;
        }
        bytes memory res = new bytes(count);
        for (uint i=0; i<count; ++i) {
            b = a % 16;
            res[count - i - 1] = toHexDigit(uint8(b));
            a /= 16;
        }
        return string(res);
    }

    function renderNFTImage(
        INftTemplate instance,
        uint256 tokenId
    ) public pure returns (string memory) {
        Shape shape = _getShape(tokenId);
        string memory color = _getColor(tokenId);

        if (shape == Shape.Circle) {
            return
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '<svg width="400" height="400" viewBox="0 0 400 400" fill="none" xmlns="http://www.w3.org/2000/svg">',
                            '<rect width="400" height="400" fill="white"/>',
                            '<circle cx="200" cy="200" r="114" stroke="#',
                            color,
                            '" stroke-width="32"/>',
                            "</svg>"
                        )
                    )
                );
        }
        else if (shape == Shape.Cross) {
            return
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '<svg width="400" height="400" viewBox="0 0 400 400" fill="none" xmlns="http://www.w3.org/2000/svg">',
                            '<rect width="400" height="400" fill="white"/>',
                            '<line x1="16" y1="-16" x2="309.279" y2="-16" transform="matrix(0.709913 0.70429 -0.709913 0.70429 73 96)" stroke="#',
                            color,
                            '" stroke-width="32" stroke-linecap="round"/>',
                            '<line x1="16" y1="-16" x2="309.279" y2="-16" transform="matrix(0.709913 -0.70429 0.709913 0.70429 96.0801 326)" stroke="#',
                            color,
                            '" stroke-width="32" stroke-linecap="round"/>',
                            "</svg>"
                        )
                    )
                );
        }
        else if (shape == Shape.Square) {
            return
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '<svg width="400" height="400" viewBox="0 0 400 400" fill="none" xmlns="http://www.w3.org/2000/svg">',
                            '<rect width="400" height="400" fill="white"/>',
                            '<rect x="96" y="96" width="208" height="208" stroke="#',
                            color,
                            '" stroke-width="32" stroke-linecap="round" stroke-linejoin="round"/>',
                            "</svg>"
                        )
                    )
                );
        }
        else {
            return
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '<svg width="400" height="400" viewBox="0 0 400 400" fill="none" xmlns="http://www.w3.org/2000/svg">',
                            '<rect width="400" height="400" fill="white"/>',
                            '<path d="M200 95L319.512 302H80.4885L200 95Z" stroke="#',
                            color,
                            '" stroke-width="32" stroke-linecap="round" stroke-linejoin="round"/>',
                            "</svg>"
                        )
                    )
                );
        }
    }

    function _generateAttributes(
        uint256 tokenId
    ) internal pure returns (string memory) {
        string memory shape = _displayShape(_getShape(tokenId));
        
        return
            string(
                abi.encodePacked(
                    "[",
                    "{",
                    '"trait_type": "Shape",',
                    '"value": ',
                    '"',
                    shape,
                    '"'
                    "}",
                    "]"
                )
            );
    }

    function tokenURI(
        INftTemplate instance,
        uint256 tokenId
    ) public pure override(ITokenRenderer) returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                tokenId.toString(),
                                '"',
                                ',"description":"What is your template number?"', // FIXME: Write something better
                                ',"external_url":"https://NftTemplate.com"',
                                ',"image":"data:image/svg+xml;base64,',
                                renderNFTImage(instance, tokenId),
                                '"',
                                ',"attributes":',
                                _generateAttributes(tokenId),
                                "}"
                            )
                        )
                    )
                )
            );
    }
}
