#!/bin/bash

set -e

pending=$(cast --to-fix 18 $(cast call --rpc-url ${RPC_URL} ${WSSCR_STRAT} "pendingRewards()(uint256)"))
echo ${pending[@]}
echo ${pending[@]:0:5}
if [[ ${pending[@]:0:1} -eq 0 ]]; then
  echo 'meow'
  exit 1
fi

if [[ ${pending[@]:0:2} -eq 0 ]]; then
  echo 'meow'
  exit 1
fi
