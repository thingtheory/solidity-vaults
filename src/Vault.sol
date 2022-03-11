// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "solidity-interfaces/beethovenx/IBeethovenxChef.sol";

interface IStrategy {
  function allocate(uint256 _amount) external;
  function deposit(uint256 _amount) external;
  function withdraw(uint256 _amount) external;
  function balance() external view returns(uint256);
}

contract Vault is ERC20, Ownable {
  bool public paused;
  IStrategy public strategy;
  IERC20 public asset;

  constructor(string memory name, string memory symbol, address _asset) ERC20(name, symbol) {
    asset = IERC20(_asset);
  }

  function setPaused(bool _paused) external onlyOwner {
    paused = _paused;
  }

  function setStrategy(address _strategy) external onlyOwner {
    strategy = IStrategy(_strategy);
    if (_strategy == address(0)) {
      return;
    }
    asset.approve(_strategy, type(uint256).max);
  }

  function recover(address _token) external onlyOwner {
    IERC20(_token).transfer(
      owner(),
      IERC20(_token).balanceOf(address(this))
    );
  }

  function deposit(uint256 _amount) public {
    require(!paused, "paused");
    // x = (currentBal + _amount) / currentBal
    // y = totalSupply * (x-1)
    // y = totalSupply * (((currentBal + _amount) / currentBal) - 1)
    // y = (totalSupply * ((currentBal + _amount) / currentBal) - totalSupply
    uint256 currentBal = strategy.balance();
    uint256 totalSupply = totalSupply();
    uint256 shares;
    if (totalSupply == 0) {
      shares = _amount;
    } else {
      shares = ((totalSupply * (currentBal + _amount)) / currentBal) - totalSupply;
    }

    _mint(msg.sender, shares);
    asset.transferFrom(msg.sender, address(this), _amount);
    strategy.deposit(_amount);
    strategy.allocate(_amount);
  }

  function withdraw(uint256 _amount) public {
    require(!paused, "paused");
    // x = (totalSupply - _amount) / totalSupply
    // y = currentBal * (1 - x)
    // y = currentBal * (1 - ((totalSupply - _amount) / totalSupply))
    // y = currentBal - currentBal * ((totalSupply - _amount) / totalSupply))
    uint256 currentBal = strategy.balance();
    uint256 totalSupply = totalSupply();
    uint256 assetAmount = currentBal - ((currentBal * (totalSupply - _amount)) / totalSupply);

    _burn(msg.sender, _amount);
    strategy.withdraw(assetAmount);
    asset.transfer(msg.sender, assetAmount);
  }
}
