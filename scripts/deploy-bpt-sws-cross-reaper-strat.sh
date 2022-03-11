#!/bin/bash

set -e

args=(
  $(cast --to-checksum-address "${VAULT}")
  $(cast --to-checksum-address "${BPT_SWS}")
  $(cast --to-checksum-address "${BPT_SWS}")
  $(cast --to-checksum-address "${BEETS}")
  $(cast --to-checksum-address "${BEETS_TO_BPT_SWS_ZAP}")
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

forge create \
  --optimize \
  --optimize-runs 200 \
  --rpc-url "${RPC_URL}" \
  --constructor-args "${args[@]}" \
  --private-key $(cat "${PRIVATE_KEY_PATH}") \
  --legacy \
  src/Strategy.sol:Strategy


