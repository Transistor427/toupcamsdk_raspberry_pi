#!/usr/bin/env bash
set -euo pipefail

# Prepare runtime files (arm64/armhf) and run Toupcam MJPEG stream.

SDK_DIR="${1:-/home/pi/toupcamsdk_raspberry_pi}"
HOST="${2:-0.0.0.0}"
PORT="${3:-8081}"
WIDTH="${4:-1280}"
HEIGHT="${5:-720}"
BANDWIDTH="${6:-60}"
PY_DIR="${SDK_DIR}/python"
LIB_DST="${PY_DIR}/libtoupcam.so"

log() {
  echo "[INFO] $*"
}

[[ -d "${SDK_DIR}" ]] || { echo "[ERROR] Не найдена папка SDK: ${SDK_DIR}" >&2; exit 1; }
[[ -f "${SDK_DIR}/prepare_runtime_aarch64.sh" ]] || { echo "[ERROR] Не найден prepare_runtime_aarch64.sh" >&2; exit 1; }

log "Подготавливаю runtime-файлы..."
bash "${SDK_DIR}/prepare_runtime_aarch64.sh" "${SDK_DIR}"

if [[ ! -f "${LIB_DST}" ]]; then
  echo "[ERROR] После подготовки не найден ${LIB_DST}" >&2
  exit 1
fi

# Make loader robust in shell and systemd runs.
export LD_LIBRARY_PATH="${PY_DIR}:/usr/local/lib:${LD_LIBRARY_PATH:-}"

log "Запускаю MJPEG поток..."
cd "${PY_DIR}"
exec python3 samples/toupcam_mjpeg_server.py \
  --host "${HOST}" \
  --port "${PORT}" \
  --width "${WIDTH}" \
  --height "${HEIGHT}" \
  --bandwidth "${BANDWIDTH}"
