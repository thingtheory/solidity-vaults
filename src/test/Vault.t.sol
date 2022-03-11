pragma solidity ^0.8.6;

import "ds-test/test.sol";
import "solidity-mocks/MockMasterChef.sol";
import "solidity-mocks/MockERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Vault.sol";
import "./CheatCodes.sol";

contract MockStrategy {
  IERC20 asset;
  uint256 _balance;

  constructor(address _asset) {
    asset = IERC20(_asset);
  }

  function balance() public view returns(uint256) {
    return _balance;
  }

  function deposit(uint256 _amount) public {
    asset.transferFrom(msg.sender, address(this), _amount);
    _balance += _amount;
  }

  function allocate(uint256 _amount) public {
  }

  function withdraw(uint256 _amount) public {
    asset.transfer(msg.sender, _amount);
    _balance -= _amount;
  }
}

contract VaultTest is DSTest {
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

  MockERC20 asset = new MockERC20("asset", "asset");
  Vault vault = new Vault("test", "test", address(asset));
  MockStrategy strat = new MockStrategy(address(asset));

  function setUp() public {
    vault.setStrategy(address(strat));

    asset.mint(address(this), 10000 ether);
  }

  function testDeposit() public {
    asset.approve(address(vault), type(uint256).max);
    uint256 balBefore = asset.balanceOf(address(this));
    vault.deposit(1 ether);

    assertEq(vault.balanceOf(address(this)), 1 ether);
    assertEq(asset.balanceOf(address(this)), balBefore - 1 ether);
  }

  function testWithdraw() public {
    asset.approve(address(vault), type(uint256).max);
    uint256 balBefore = asset.balanceOf(address(this));
    vault.deposit(1 ether);

    vault.withdraw(1 ether);

    assertEq(vault.balanceOf(address(this)), 0);
    assertEq(asset.balanceOf(address(this)), balBefore);
  }

  function testDepositWithGrowth() public {
    asset.approve(address(vault), type(uint256).max);
    vault.deposit(1 ether);
    asset.approve(address(strat), type(uint256).max);
    strat.deposit(3 ether);

    vault.deposit(1 ether);

    assertEq(vault.balanceOf(address(this)), 125 ether / 100); // 1.25
  }

  function testWithdrawWithGrowth() public {
    asset.approve(address(vault), type(uint256).max);
    vault.deposit(1 ether);
    asset.approve(address(strat), type(uint256).max);
    strat.deposit(3 ether);
    vault.deposit(1 ether);
    uint256 balBefore = asset.balanceOf(address(this));

    vault.withdraw(1 ether/2);

    assertEq(asset.balanceOf(address(this)), balBefore+2 ether);
  }
}

