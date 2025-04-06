#!/usr/bin/env bash

set -euo pipefail

FILE_OUTPUT=$(file "$LIB")
if ! echo "$FILE_OUTPUT" | grep -q "arm64"; then
  echo "Missing 'arm64' architecture:"
  echo "$FILE_OUTPUT"
  exit 1
fi

if ! echo "$FILE_OUTPUT" | grep -q "x86_64"; then
  echo "Missing 'x86_64' architecture:"
  echo "$FILE_OUTPUT"
  exit 1
fi

echo "macOS test passed"
