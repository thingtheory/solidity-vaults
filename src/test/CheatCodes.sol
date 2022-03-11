interface CheatCodes {
  function roll(uint256 _incrementBlock) external;
  function prank(address _caller) external;
  function expectRevert(bytes calldata) external;
  function startPrank(address, address) external;
  function stopPrank() external;
}
