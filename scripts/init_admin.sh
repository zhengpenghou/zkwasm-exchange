#!/bin/bash
set -euo pipefail

# This script initializes the admin key securely
# Usage: init_admin.sh <key_file_or_secret> <output_pubkey_file>

if [ $# -ne 2 ]; then
  echo "Usage: $0 <key_file_or_secret> <output_pubkey_file>"
  exit 1
fi

KEY_SOURCE="$1"
OUTPUT_FILE="$2"

# Create a temporary copy if the source is a read-only file (like Docker secrets)
if [ -s "$KEY_SOURCE" ] && [ ! -w "$KEY_SOURCE" ]; then
  echo "Creating temporary copy of key file for processing..."
  TEMP_KEY_FILE=$(mktemp)
  chmod 600 "$TEMP_KEY_FILE"
  cat "$KEY_SOURCE" > "$TEMP_KEY_FILE"
  
  # Use the temporary file for the node script
  node ./ts/node_modules/zkwasm-ts-server/src/init_admin.js "$TEMP_KEY_FILE" "$OUTPUT_FILE"
  
  # Securely remove the temporary file
  shred -u "$TEMP_KEY_FILE"
else
  # Use the source file directly if it's writable
  node ./ts/node_modules/zkwasm-ts-server/src/init_admin.js "$KEY_SOURCE" "$OUTPUT_FILE"
fi

echo "Admin key initialized successfully"
