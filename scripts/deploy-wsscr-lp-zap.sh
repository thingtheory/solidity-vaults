#!/bin/bash

set -e

args=(
  $(cast --to-checksum-address "${BEETS_VAULT}")
  $(cast --to-checksum-address "${BEETS}")
  $(cast --to-checksum-address "${WSSCR}")
  $(cast --to-checksum-address "${WFTM}")
  $(cast --to-checksum-address "${DAI}")
  $(cast --to-checksum-address "${BPT_SWS}")
  "${WSSCR_DAI_POOL_ID}"
  "${WFTM_DAI_POOL_ID}"
  "${BEETS_WFTM_POOL_ID}"
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

forge create \
  --optimize \
  --optimize-runs 200 \
  --rpc-url "${RPC_URL}" \
  --constructor-args "${args[@]}" \
  --private-key $(cat "${PRIVATE_KEY_PATH}") \
  --legacy \
  src/zaps/BeetsToBptSws.sol:BeetsToBptSws


