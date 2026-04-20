#!/usr/bin/env bash
set -euo pipefail

# Save one frame from local Toupcam snapshot endpoint.

SNAPSHOT_URL="${SNAPSHOT_URL:-http://127.0.0.1:8081/snapshot.jpg}"
OUT_DIR="${1:-/home/pi/printer_data/timelapse/toupcam}"

mkdir -p "${OUT_DIR}"

TS="$(date +%Y%m%d_%H%M%S_%3N)"
OUT_FILE="${OUT_DIR}/frame_${TS}.jpg"

curl -fsS --max-time 5 "${SNAPSHOT_URL}" -o "${OUT_FILE}"
echo "[INFO] Frame saved: ${OUT_FILE}"
