#!/usr/bin/env bash
set -euo pipefail

# Prepare runtime files (aarch64) and run Toupcam MJPEG stream.

SDK_DIR="${1:-/home/pi/toupcamsdk_raspberry_pi}"
HOST="${2:-0.0.0.0}"
PORT="${3:-8081}"
WIDTH="${4:-1280}"
HEIGHT="${5:-720}"
BANDWIDTH="${6:-60}"

log() {
  echo "[INFO] $*"
}

[[ -d "${SDK_DIR}" ]] || { echo "[ERROR] Не найдена папка SDK: ${SDK_DIR}" >&2; exit 1; }
[[ -f "${SDK_DIR}/prepare_runtime_aarch64.sh" ]] || { echo "[ERROR] Не найден prepare_runtime_aarch64.sh" >&2; exit 1; }

log "Подготавливаю runtime-файлы..."
bash "${SDK_DIR}/prepare_runtime_aarch64.sh" "${SDK_DIR}"

log "Запускаю MJPEG поток..."
cd "${SDK_DIR}/python"
exec python3 samples/toupcam_mjpeg_server.py \
  --host "${HOST}" \
  --port "${PORT}" \
  --width "${WIDTH}" \
  --height "${HEIGHT}" \
  --bandwidth "${BANDWIDTH}"
