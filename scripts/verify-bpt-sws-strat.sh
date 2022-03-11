#!/bin/bash

set -e

args=(
  $(cast --to-checksum-address "${VAULT}")
  $(cast --to-checksum-address "${FBEETS_CRYPT}")
  $(cast --to-checksum-address "${BPT_SWS}")
  $(cast --to-checksum-address "${BEETS}")
  $(cast --to-checksum-address "${BEETS_TO_REAPER_ZAP}")
  $(cast --to-checksum-address "${CHEF}")
  "${PID}"
)
echo "${args[@]}"

if [[ -z "${RPC_URL}" ]]; then
  echo "RPC_URL is blank"
  exit 1
fi

if [[ -z "${PRIVATE_KEY_PATH}" ]]; then
  echo "PRIVATE_KEY_PATH is blank"
  exit 1
fi

cast abi-encode "constructor(address,address,address,address,address,address,bytes32)" "${args[@]}"

echo "${encodedArgs}"

#export RUST_BACKTRACE=full
forge verify-contract \
  --chain-id=250 \
  --constructor-args "${encodedArgs}" \
  --compiler-version "0.8.6+commit.11564f7e" \
  --num-of-optimizations 200 \
  "${ADDRESS}" \
  src/Strategy.sol:Strategy \
  "${ETHERSCAN_API_KEY}"


