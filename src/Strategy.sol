// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "solidity-interfaces/beethovenx/IBeethovenxChef.sol";

interface IZap {
  function zap(uint256 _amount, uint256 _minimumReceived) external;
}

contract Strategy is Ownable {
  IBeethovenxChef public immutable chef;
  IZap public immutable zap;
  IERC20 public immutable asset;
  IERC20 public immutable reward;
  IERC20 public immutable want;
  uint256 public immutable chefPID;
  address public immutable vault;
  bool public paused;

  event Paused(bool indexed _paused);

  modifier onlyVault() {
    require(msg.sender == vault || msg.sender == owner(), "only vault");
    _;
  }

  constructor(address _vault, address _wantToken, address _asset, address _reward, address _zap, address _chef, uint256 _chefPID) {
    chef = IBeethovenxChef(_chef);
    asset = IERC20(_asset);
    reward = IERC20(_reward);
    want = IERC20(_wantToken);
    zap = IZap(_zap);
    chefPID = _chefPID;
    vault = _vault;
  }

  function setPaused(bool _paused) external onlyOwner {
    paused = _paused;
    emit Paused(paused);
  }

  function recover(address _token) external onlyOwner {
    IERC20(_token).transfer(
      owner(),
      IERC20(_token).balanceOf(address(this))
    );
  }

  function retire() public virtual onlyOwner {
    paused = true;

    _harvest();
    _withdraw(balance());
    _withdrawReward(rewardBalance());
    _withdrawWant(wantBalance());

    asset.approve(address(chef), 0);
    reward.approve(address(zap), 0);
  }

  function allocate(uint256 _amount) public virtual onlyVault {
    require(!paused, "paused");

    _allocate(_amount);
  }

  function deposit(uint256 _amount) public virtual onlyVault {
    require(!paused, "paused");

    asset.transferFrom(msg.sender, address(this), _amount);
  }

  function withdraw(uint256 _amount) public virtual onlyVault {
    require(!paused, "paused");
    _withdraw(_amount);
  }

  function withdrawReward(uint256 _amount) public onlyVault {
    require(!paused, "paused");
    _withdrawReward(_amount);
  }

  function withdrawWant(uint256 _amount) public onlyVault {
    require(!paused, "paused");
    _withdrawWant(_amount);
  }

  // anyone can call harvest
  function harvest() public virtual {
    require(!paused, "paused");

    _harvest();
    _allocate(asset.balanceOf(address(this)));
  }

  function balance() public view virtual returns (uint256) {
    (uint256 _balance, ) = chef.userInfo(chefPID, address(this));
    return asset.balanceOf(address(this)) + _balance;
  }

  function rewardBalance() public view returns (uint256) {
    return reward.balanceOf(address(this));
  }

  function wantBalance() public view returns (uint256) {
    return want.balanceOf(address(this));
  }

  function pendingRewards() public view returns (uint256) {
    return chef.pendingBeets(chefPID, address(this));
  }

  function _minimumReceived(uint256 _amount) internal view returns (uint256) {
    return 0; // TODO
  }

  // anyone can call harvest
  function _harvest() internal {
    chef.harvest(chefPID, address(this));
    uint256 amount = rewardBalance();

    reward.approve(address(zap), amount);
    zap.zap(amount, _minimumReceived(amount));
  }

  function _allocate(uint256 _amount) internal {
    asset.approve(address(chef), _amount);

    chef.deposit(chefPID, _amount, address(this));
  }

  function _withdraw(uint256 _amount) internal {
    require(_amount <= balance(), "exceeds balance");

    uint256 bal = asset.balanceOf(address(this));

    if (_amount > bal) {
      chef.withdrawAndHarvest(chefPID, _amount - bal, address(this));
    }
    require(asset.balanceOf(address(this)) >= _amount, "foobar");
    asset.transfer(msg.sender, _amount);
  }

  function _withdrawWant(uint256 _amount) internal {
    require(_amount <= wantBalance(), "exceeds want balance");

    want.transfer(msg.sender, _amount);
  }

  function _withdrawReward(uint256 _amount) internal {
    require(_amount <= rewardBalance(), "exceeds reward balance");

    reward.transfer(msg.sender, _amount);
  }
}
