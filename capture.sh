#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p bash -c '[[ -n "${CAPTURE_URL:-}" ]] || { echo "CAPTURE_URL is required" >&2; exit 1; }'
/usr/bin/time -p bash -c '[[ -n "${CAPTURE_DIR:-}" ]] || { echo "CAPTURE_DIR is required" >&2; exit 1; }'
/usr/bin/time -p bash -c '[[ -n "${RUNTIME_DIR:-}" ]] || { echo "RUNTIME_DIR is required" >&2; exit 1; }'
/usr/bin/time -p mkdir -p "$CAPTURE_DIR"
/usr/bin/time -p bash -c '[[ -f "$0/scripts/default-capture.mjs" ]] || { echo "default-capture.mjs missing" >&2; exit 1; }' "$RUNTIME_DIR"
/usr/bin/time -p node "$RUNTIME_DIR/scripts/default-capture.mjs"
