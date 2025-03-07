#!/bin/bash
set -euo pipefail
# This script cleans environment variables to ensure they don't contain newlines or other problematic characters

# Validate required variables
if [ -z "${USER_ADDRESS:-}" ]; then
  echo "ERROR: USER_ADDRESS is not set"
  exit 1
fi

if [ -z "${USER_PRIVATE_ACCOUNT:-}" ] && [ -z "${SETTLER_PRIVATE_ACCOUNT:-}" ]; then
  echo "ERROR: Neither USER_PRIVATE_ACCOUNT nor SETTLER_PRIVATE_ACCOUNT is set"
  exit 1
fi

# Clean the environment variables
USER_ADDRESS_CLEAN=$(echo "${USER_ADDRESS:-}" | tr -d '\n\r')
USER_PRIVATE_ACCOUNT_CLEAN=$(echo "${USER_PRIVATE_ACCOUNT:-}" | tr -d '\n\r')
SETTLER_PRIVATE_ACCOUNT_CLEAN=$(echo "${SETTLER_PRIVATE_ACCOUNT:-}" | tr -d '\n\r')
CHAIN_ID_CLEAN=$(echo "${CHAIN_ID:-11155111}" | tr -d '\n\r')
CREATOR_ONLY_ADD_PROVE_TASK_CLEAN=$(echo "${CREATOR_ONLY_ADD_PROVE_TASK:-true}" | tr -d '\n\r')

# Create a secure .env file with proper permissions
ENV_FILE=".env"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

# Create the .env file with clean variables
echo "USER_ADDRESS=\"$USER_ADDRESS_CLEAN\"" > "$ENV_FILE"

# Only add private keys if they exist
if [ -n "$USER_PRIVATE_ACCOUNT_CLEAN" ]; then
  echo "USER_PRIVATE_ACCOUNT=\"$USER_PRIVATE_ACCOUNT_CLEAN\"" >> "$ENV_FILE"
fi

if [ -n "$SETTLER_PRIVATE_ACCOUNT_CLEAN" ]; then
  echo "SETTLER_PRIVATE_ACCOUNT=\"$SETTLER_PRIVATE_ACCOUNT_CLEAN\"" >> "$ENV_FILE"
fi

echo "CHAIN_ID=\"$CHAIN_ID_CLEAN\"" >> "$ENV_FILE"
echo "CHART_NAME=\"zkwasm-exchange\"" >> "$ENV_FILE"
echo "CREATOR_ONLY_ADD_PROVE_TASK=\"$CREATOR_ONLY_ADD_PROVE_TASK_CLEAN\"" >> "$ENV_FILE"

# Output for debugging (masking private keys)
echo "Cleaned environment variables:"
echo "  USER_ADDRESS: ${USER_ADDRESS_CLEAN:0:6}...${USER_ADDRESS_CLEAN: -4}"
if [ -n "$USER_PRIVATE_ACCOUNT_CLEAN" ]; then
  echo "  USER_PRIVATE_ACCOUNT: [Set]"
else
  echo "  USER_PRIVATE_ACCOUNT: [Not Set]"
fi
if [ -n "$SETTLER_PRIVATE_ACCOUNT_CLEAN" ]; then
  echo "  SETTLER_PRIVATE_ACCOUNT: [Set]"
else
  echo "  SETTLER_PRIVATE_ACCOUNT: [Not Set]"
fi
echo "  CHAIN_ID: $CHAIN_ID_CLEAN"
echo "  CREATOR_ONLY_ADD_PROVE_TASK: $CREATOR_ONLY_ADD_PROVE_TASK_CLEAN"

echo "Environment file created successfully with secure permissions (600)"
