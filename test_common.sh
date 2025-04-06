#!/usr/bin/env bash

set -euo pipefail

if [ ! -f "$LIB" ]; then
  echo "Library does not exist: $LIB"
  exit 1
fi

if ! nm -a "$LIB" | grep -q "rtsan_realtime_enter"; then
  echo "Missing required symbol: rtsan_realtime_enter"
  exit 1
fi

echo "Common tests passed"
