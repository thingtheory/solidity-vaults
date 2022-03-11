// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "solidity-interfaces/beethovenx/IBeetsBar.sol";
import "solidity-interfaces/beethovenx/IBalancerVault.sol";

contract BeetsToBptSws is Ownable {
  IBalancerVault public immutable balancerVault;
  IERC20         public immutable beets;
  IERC20         public immutable wftm;
  IERC20         public immutable dai;
  IERC20         public immutable wsSCR;
  IERC20         public immutable swsBPT;
  bytes32        public immutable wftmDaiPoolID;
  bytes32        public immutable beetsWftmPoolID;
  bytes32        public immutable swsPoolID;
  IAsset[]       public zapAssets;
  uint256   public fee = 0; // fee in BPS
  address   public feeReceiver;
  address[] public lpTokens;

  mapping(address=>bool) public feeExempt;
  mapping(address=>uint256) public assetIndex;

  event SetFee(address indexed _feeReceiver, uint256 _fee);
  event SetFeeExempt(address indexed _caller, bool _exempt);

  constructor(
    address _vault,
    address _beets,
    address _wsSCR,
    address _wftm,
    address _dai,
    address _swsBPT,
    bytes32 _swsPoolID,
    bytes32 _wftmDaiPoolID,
    bytes32 _beetsWftmPoolID
  ) {
    balancerVault = IBalancerVault(_vault);

    beets = IERC20(_beets);
    wftm = IERC20(_wftm);
    dai = IERC20(_dai);
    wsSCR = IERC20(_wsSCR);
    swsBPT = IERC20(_swsBPT);

    lpTokens.push(_dai);
    lpTokens.push(_wsSCR);

    swsPoolID = _swsPoolID;
    wftmDaiPoolID = _wftmDaiPoolID;
    beetsWftmPoolID = _beetsWftmPoolID;

    IERC20(_beets).approve(_vault, type(uint256).max);
    IERC20(_dai).approve(_vault, type(uint256).max);

    zapAssets.push(IAsset(_beets));
    assetIndex[_beets] = zapAssets.length - 1;
    zapAssets.push(IAsset(_wftm));
    assetIndex[_wftm] = zapAssets.length - 1;
    zapAssets.push(IAsset(_dai));
    assetIndex[_dai] = zapAssets.length - 1;
  }

  function destroy() external onlyOwner {
    selfdestruct(payable(owner()));
  }

  function recover(address _token) external onlyOwner {
    IERC20(_token).transfer(
      owner(),
      IERC20(_token).balanceOf(address(this))
    );
  }

  function setFee(uint256 _fee, address _feeReceiver) external onlyOwner {
    if (_fee != 0) {
      require(_feeReceiver != address(0), "zero receiver");
    }

    require(_fee <= 500, "fee limit"); // 5%
    fee = _fee;
    feeReceiver = _feeReceiver;

    emit SetFee(_feeReceiver, _fee);
  }

  function setFeeExempt(bool _exempt, address _caller) external onlyOwner {
    feeExempt[_caller] = _exempt;

    emit SetFeeExempt(_caller, _exempt);
  }

  function zapAll(uint256 _minimumReceived) external {
    zap(beets.balanceOf(msg.sender), _minimumReceived);
  }

  function zap(uint256 _amount, uint256 _minimumReceived) public {
    beets.transferFrom(msg.sender, address(this), _amount);

    IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](2);
    swaps[0] = IBalancerVault.BatchSwapStep(
      beetsWftmPoolID,
      assetIndex[address(beets)],
      assetIndex[address(wftm)],
      _amount,
      new bytes(0)
    );
    // Use output amount from previous swap
    uint256 _wftmAmount = 0;
    swaps[1] = IBalancerVault.BatchSwapStep(
      wftmDaiPoolID,
      assetIndex[address(wftm)],
      assetIndex[address(dai)],
      _wftmAmount,
      new bytes(0)
    );
    int256[] memory limits = new int256[](zapAssets.length);
    limits[0] = int256(_amount);
    limits[1] = type(int256).max;
    limits[2] = type(int256).max;
    balancerSwap(zapAssets, swaps, limits);

    balancerJoin(swsPoolID, address(dai), dai.balanceOf(address(this)));
    uint256 got = swsBPT.balanceOf(address(this));

    require(got >= _minimumReceived, "not enough");
    swsBPT.transfer(msg.sender, got);
  }

  function balancerSwap(
    IAsset[] storage _swapAssets,
    IBalancerVault.BatchSwapStep[] memory swaps,
    int256[] memory limits
  ) internal {
    balancerVault.batchSwap(
      IBalancerVault.SwapKind.GIVEN_IN,
      swaps,
      _swapAssets,
      IBalancerVault.FundManagement(
        address(this),
        false,
        payable(address(this)),
        false
      ),
      limits,
      block.timestamp);
  }

  function balancerJoin(bytes32 _poolId, address _tokenIn, uint256 _amountIn) internal {
    uint256[] memory amounts = new uint256[](lpTokens.length);
    for (uint256 i = 0; i < amounts.length; i++) {
        amounts[i] = lpTokens[i] == _tokenIn ? _amountIn : 0;
    }
    bytes memory userData = abi.encode(1, amounts, 1);

    IBalancerVault.JoinPoolRequest memory request = IBalancerVault.JoinPoolRequest(lpTokens, amounts, userData, false);
    balancerVault.joinPool(_poolId, address(this), address(this), request);
  }
}
