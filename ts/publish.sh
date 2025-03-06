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

# Set default values for environment variables if not provided
USER_ADDRESS=${USER_ADDRESS:-"0xd8f157Cc95Bc40B4F0B58eb48046FebedbF26Bde"}
USER_PRIVATE_ACCOUNT=${USER_PRIVATE_ACCOUNT:-"2763537251e2f27dc6a30179e7bf1747239180f45b92db059456b7da8194995a"}
SETTLER_PRIVATE_ACCOUNT=${SETTLER_PRIVATE_ACCOUNT:-"$USER_PRIVATE_ACCOUNT"}
CHAIN_ID=${CHAIN_ID:-11155111}
CHART_NAME=${CHART_NAME:-"zkwasm-exchange"}
AUTO_SUBMIT=${AUTO_SUBMIT:-"true"}
CREATOR_ONLY_ADD_PROVE_TASK=${CREATOR_ONLY_ADD_PROVE_TASK:-"true"}

# Use SETTLER_PRIVATE_ACCOUNT as fallback if USER_PRIVATE_ACCOUNT is not set
if [ -z "$USER_PRIVATE_ACCOUNT" ] && [ -n "$SETTLER_PRIVATE_ACCOUNT" ]; then
  USER_PRIVATE_ACCOUNT=$SETTLER_PRIVATE_ACCOUNT
fi

# Validate required variables
if [ -z "$USER_ADDRESS" ]; then
  echo "ERROR: USER_ADDRESS is not set"
  echo "Please set USER_ADDRESS environment variable or update the script with your address"
  exit 1
fi

if [ -z "$USER_PRIVATE_ACCOUNT" ]; then
  echo "ERROR: Neither USER_PRIVATE_ACCOUNT nor SETTLER_PRIVATE_ACCOUNT is set"
  echo "Please set one of these environment variables or update the script with your private key"
  exit 1
fi

# Log what we're doing (without exposing private keys)
echo "Publishing WASM image with:"
echo "  User Address: $USER_ADDRESS"
echo "  Chain ID: $CHAIN_ID"
echo "  Chart Name: $CHART_NAME"
echo "  Auto Submit: $AUTO_SUBMIT"
echo "  Creator Only Add Prove Task: $CREATOR_ONLY_ADD_PROVE_TASK"

# Check if the WASM file exists
if [ ! -f "./node_modules/zkwasm-ts-server/src/application/application_bg.wasm" ]; then
  echo "ERROR: WASM file not found at ./node_modules/zkwasm-ts-server/src/application/application_bg.wasm"
  echo "Please ensure the WASM file is in the correct location"
  exit 1
fi

# Check if zkwasm-service-cli is installed
if [ ! -d "./node_modules/zkwasm-service-cli" ]; then
  echo "Installing zkwasm-service-cli..."
  npm install zkwasm-service-cli
fi

# Execute the command with environment variables
echo "Running zkwasm-service-cli addimage command..."
node ./node_modules/zkwasm-service-cli/dist/index.js addimage \
  -r "https://rpc.zkwasmhub.com:8090" \
  -p "./node_modules/zkwasm-ts-server/src/application/application_bg.wasm" \
  -u "$USER_ADDRESS" \
  -x "$USER_PRIVATE_ACCOUNT" \
  -d "$CHART_NAME Application" \
  -c 22 \
  --auto_submit_network_ids $CHAIN_ID \
  --creator_only_add_prove_task $CREATOR_ONLY_ADD_PROVE_TASK

echo "WASM image publishing completed"
