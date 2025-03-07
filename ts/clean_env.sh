#!/bin/bash
# This script cleans environment variables to ensure they don't contain newlines or other problematic characters

# Clean the environment variables
USER_ADDRESS_CLEAN=$(echo "$USER_ADDRESS" | tr -d '\n\r')
USER_PRIVATE_ACCOUNT_CLEAN=$(echo "$USER_PRIVATE_ACCOUNT" | tr -d '\n\r')
SETTLER_PRIVATE_ACCOUNT_CLEAN=$(echo "$SETTLER_PRIVATE_ACCOUNT" | tr -d '\n\r')

# Create the .env file with clean variables
echo "USER_ADDRESS=\"$USER_ADDRESS_CLEAN\"" > .env
echo "USER_PRIVATE_ACCOUNT=\"$USER_PRIVATE_ACCOUNT_CLEAN\"" >> .env
echo "SETTLER_PRIVATE_ACCOUNT=\"$SETTLER_PRIVATE_ACCOUNT_CLEAN\"" >> .env
echo "CHAIN_ID=\"${CHAIN_ID}\"" >> .env
echo "CHART_NAME=\"zkwasm-exchange\"" >> .env
echo "CREATOR_ONLY_ADD_PROVE_TASK=\"${CREATOR_ONLY_ADD_PROVE_TASK}\"" >> .env

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
