#!/bin/bash
set -euo pipefail

# Script to update the zkwasm-typescript-mini-server dependency
cd "$(dirname "$0")/../ts" || exit 1
npm install 'https://gitpkg.vercel.app/DelphinusLab/zkwasm-typescript-mini-server/ts?main'
