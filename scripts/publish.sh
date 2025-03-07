#!/bin/bash
set -euo pipefail

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file"
  source .env
elif [ -f ../.env ]; then
  echo "Loading environment variables from parent directory .env file"
  source ../.env
fi

# Set default values for non-sensitive environment variables if not provided
CHAIN_ID=${CHAIN_ID:-11155111}
CHART_NAME=${CHART_NAME:-"zkwasm-exchange"}
AUTO_SUBMIT=${AUTO_SUBMIT:-"true"}
CREATOR_ONLY_ADD_PROVE_TASK=${CREATOR_ONLY_ADD_PROVE_TASK:-"true"}

# Use SETTLER_PRIVATE_ACCOUNT as fallback if USER_PRIVATE_ACCOUNT is not set
if [ -z "${USER_PRIVATE_ACCOUNT:-}" ] && [ -n "${SETTLER_PRIVATE_ACCOUNT:-}" ]; then
  USER_PRIVATE_ACCOUNT=$SETTLER_PRIVATE_ACCOUNT
fi

# Validate required variables with improved security checks
if [ -z "${USER_ADDRESS:-}" ]; then
  echo "ERROR: USER_ADDRESS is not set"
  echo "Please set USER_ADDRESS environment variable"
  exit 1
fi

if [ -z "${USER_PRIVATE_ACCOUNT:-}" ]; then
  echo "ERROR: Neither USER_PRIVATE_ACCOUNT nor SETTLER_PRIVATE_ACCOUNT is set"
  echo "Please set one of these environment variables"
  exit 1
fi

# Log what we're doing (without exposing private keys)
echo "Publishing WASM image with:"
echo "  User Address: ${USER_ADDRESS:0:6}...${USER_ADDRESS: -4}"
echo "  Chain ID: $CHAIN_ID"
echo "  Chart Name: $CHART_NAME"
echo "  Auto Submit: $AUTO_SUBMIT"
echo "  Creator Only Add Prove Task: $CREATOR_ONLY_ADD_PROVE_TASK"

# Check if the WASM file exists
WASM_PATH="../ts/node_modules/zkwasm-ts-server/src/application/application_bg.wasm"
if [ -f "$WASM_PATH" ]; then
  WASM_FILE="$WASM_PATH"
elif [ -f "./node_modules/zkwasm-ts-server/src/application/application_bg.wasm" ]; then
  WASM_FILE="./node_modules/zkwasm-ts-server/src/application/application_bg.wasm"
else
  echo "ERROR: WASM file not found"
  echo "Please ensure the WASM file is in the correct location"
  exit 1
fi

# Check if zkwasm-service-cli is installed
if [ ! -d "../ts/node_modules/zkwasm-service-cli" ] && [ ! -d "./node_modules/zkwasm-service-cli" ]; then
  echo "Installing zkwasm-service-cli..."
  cd ../ts && npm install zkwasm-service-cli && cd -
fi

# Determine CLI path
if [ -d "../ts/node_modules/zkwasm-service-cli" ]; then
  CLI_PATH="../ts/node_modules/zkwasm-service-cli/dist/index.js"
else
  CLI_PATH="./node_modules/zkwasm-service-cli/dist/index.js"
fi

# Create a temporary file for the private key to avoid command line exposure
TMP_KEY_FILE=$(mktemp)
chmod 600 "$TMP_KEY_FILE"
echo -n "$USER_PRIVATE_ACCOUNT" > "$TMP_KEY_FILE"

trap 'rm -f "$TMP_KEY_FILE"' EXIT INT TERM

# Execute the command with environment variables
echo "Running zkwasm-service-cli addimage command..."
node "$CLI_PATH" addimage \
  -r "https://rpc.zkwasmhub.com:8090" \
  -p "$WASM_FILE" \
  -u "$USER_ADDRESS" \
  -f "$TMP_KEY_FILE" \
  -n "$CHART_NAME" \
  -d "$CHART_NAME Application" \
  -c 22 \
  --auto_submit_network_ids $CHAIN_ID \
  --creator_only_add_prove_task $CREATOR_ONLY_ADD_PROVE_TASK

# Securely remove the temporary key file
rm -f "$TMP_KEY_FILE"
trap - EXIT INT TERM

echo "WASM image publishing completed successfully"
