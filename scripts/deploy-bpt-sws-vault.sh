#!/bin/bash

set -e

args=(
  '"Test BPT-SWS Vault"'
  "vTestBPTSWS"
  $(cast --to-checksum-address "${BPT_SWS}")
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
  src/Vault.sol:Vault


