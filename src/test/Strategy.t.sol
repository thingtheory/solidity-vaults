pragma solidity ^0.8.6;

import "ds-test/test.sol";
import "solidity-mocks/MockMasterChef.sol";
import "solidity-mocks/MockERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Strategy.sol";
import "./CheatCodes.sol";

contract MockZap {
  IERC20 inToken;
  IERC20 outToken;
  uint256 ratio;

  // only use tokens with 18 decimals
  constructor(address _in, address _out, uint256 _ratio) {
    inToken = IERC20(_in);
    outToken = IERC20(_out);
    ratio = _ratio;
  }

  function zap(uint256 _amount, uint256 _minReceived) public {
    inToken.transferFrom(msg.sender, address(this), _amount);
    uint256 outAmt = (_amount * ratio) / 1e18;
    require(outAmt >= _minReceived, "too little");
    outToken.transfer(msg.sender, outAmt);
  }
}

contract StrategyTest is DSTest {
  MockERC20 asset = new MockERC20("asset", "asset");
  MockERC20 reward = new MockERC20("reward", "reward");
  MockERC20 want = asset;
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

  address[] chefTokens = [address(asset)];

  uint256 chefPid = 0;

  address vault;

  MockMasterChef chef = new MockMasterChef(chefTokens, address(reward));
  MockZap zap = new MockZap(address(reward), address(want), 2*1e18);
  Strategy strat = new Strategy(
    vault,
    address(asset),
    address(want),
    address(reward),
    address(zap),
    address(chef),
    chefPid
  );

  function setUp() public {
    vault = address(this);
    asset.mint(address(this), 10000 ether);
    asset.mint(address(zap), 10000 ether);
  }

  function testDeposit() public {
    asset.approve(address(strat), type(uint256).max);
    uint256 amount = 1 ether;

    strat.deposit(amount);

    assertEq(strat.balance(), amount);
    assertEq(asset.balanceOf(address(strat)), amount);
  }

  function testAllocate() public {
    asset.approve(address(strat), type(uint256).max);
    uint256 amount = 1 ether;

    strat.deposit(amount);
    strat.allocate(amount/2);

    assertEq(strat.balance(), amount);
    assertEq(asset.balanceOf(address(strat)), amount/2);
  }

  function testWithdraw() public {
    asset.approve(address(strat), type(uint256).max);
    uint256 amount = 1 ether;
    uint256 balBefore = asset.balanceOf(address(this));
    strat.deposit(amount);
    strat.allocate(amount/2);

    strat.withdraw(amount);

    assertEq(strat.balance(), 0);
    assertEq(asset.balanceOf(address(strat)), 0);
    assertEq(asset.balanceOf(address(this)), balBefore);
  }

  function testHarvest() public {
    asset.approve(address(strat), type(uint256).max);
    uint256 amount = 1 ether;
    strat.deposit(amount);
    strat.allocate(amount);
    uint256 balBefore = strat.balance();

    cheats.roll(100);

    strat.harvest();

    assertEq(asset.balanceOf(address(strat)), 0);
    assertEq(reward.balanceOf(address(strat)), 0);
    assertGt(strat.balance(), balBefore);
  }

  function testCannotDepositUnprivileged() public {
    cheats.startPrank(address(1), address(1));
    asset.approve(address(strat), type(uint256).max);
    uint256 amount = 1 ether;

    cheats.expectRevert(bytes("only vault"));
    strat.deposit(amount);
  }

  function testCannotWithdrawUnprivileged() public {
    cheats.startPrank(address(1), address(1));

    cheats.expectRevert(bytes("only vault"));
    strat.withdraw(1);
  }

  function testCannotWithdrawWantUnprivileged() public {
    cheats.startPrank(address(1), address(1));

    cheats.expectRevert(bytes("only vault"));
    strat.withdrawWant(1);
  }

  function testCannotWithdrawRewardUnprivileged() public {
    cheats.startPrank(address(1), address(1));

    cheats.expectRevert(bytes("only vault"));
    strat.withdrawReward(1);
  }

  function testCannotSetPausedUnprivileged() public {
    cheats.startPrank(address(1), address(1));

    cheats.expectRevert(bytes("Ownable: caller is not the owner"));
    strat.setPaused(true);
  }

  function testCannotRetireUnprivileged() public {
    cheats.startPrank(address(1), address(1));

    cheats.expectRevert(bytes("Ownable: caller is not the owner"));
    strat.retire();
  }

  function testCannotRecoverUnprivileged() public {
    cheats.startPrank(address(1), address(1));

    cheats.expectRevert(bytes("Ownable: caller is not the owner"));
    strat.recover(address(asset));
  }

  function testHarvestUnprivileged() public {
    cheats.startPrank(address(1), address(1));

    strat.harvest();
  }
}
