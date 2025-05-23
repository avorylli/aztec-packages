#!/usr/bin/env bash
set -eu

REPO=$(git rev-parse --show-toplevel)

# Get the name of the script without the path and extension
SCRIPT_NAME=$(basename "$0" .sh)

# Redirect stdout and stderr to <script_name>.log while also printing to the console
exec > >(tee -a "$(dirname $0)/logs/${SCRIPT_NAME}.log") 2> >(tee -a "$(dirname $0)/logs/${SCRIPT_NAME}.log" >&2)

# Starts the Boot Node

# Set environment variables
export PORT=${PORT:-"8080"}
export DEBUG=${DEBUG:-""}
export LOG_LEVEL=${LOG_LEVEL:-"verbose"}
export ETHEREUM_HOSTS=${ETHEREUM_HOSTS:-"http://127.0.0.1:8545"}
export L1_CONSENSUS_HOST_URLS=${L1_CONSENSUS_HOST_URLS:-}
export P2P_ENABLED="true"
export VALIDATOR_DISABLED="true"
export BLOB_SINK_URL="http://127.0.0.1:${BLOB_SINK_PORT:-5053}"
export SEQ_MIN_TX_PER_BLOCK="1"
export P2P_IP="127.0.0.1"
export P2P_PORT="40400"
export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT="${OTEL_EXPORTER_OTLP_METRICS_ENDPOINT:-}"
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="${OTEL_EXPORTER_OTLP_TRACES_ENDPOINT:-}"
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT="${OTEL_EXPORTER_OTLP_LOGS_ENDPOINT:-}"
export OTEL_RESOURCE_ATTRIBUTES="service.name=boot-node"
export VALIDATOR_PRIVATE_KEY=${VALIDATOR_PRIVATE_KEY:-"0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"}
export TEST_ACCOUNTS="true"

echo "Waiting for l1 contracts to be deployed..."
until [ -f "$REPO"/yarn-project/end-to-end/scripts/native-network/state/l1-contracts.env ]; do
  sleep 1
done
echo "Done waiting."

source "$REPO"/yarn-project/end-to-end/scripts/native-network/state/l1-contracts.env

# Get the chain ID from the Ethereum node
source "$REPO"/yarn-project/end-to-end/scripts/native-network/utils/get-chain-id.sh
export L1_CHAIN_ID=${L1_CHAIN_ID:-31337}

function filter_noise() {
  grep -Ev "node_getProvenBlockNumber|getBlocks|Last block mined|Running random nodes query|Not creating block because not enough txs in the pool|Peers to connect"
}

# Start the Aztec node with the sequencer and archiver
node --no-warnings "$REPO"/yarn-project/aztec/dest/bin/index.js start --node --archiver --sequencer 2>&1 | filter_noise
