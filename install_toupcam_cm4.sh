#!/usr/bin/env bash
set -euo pipefail

# Install only required dependencies for Toupcam stream on Raspberry Pi.

log() {
  echo "[INFO] $*"
}

ARCH="$(uname -m)"
if [[ "${ARCH}" != "aarch64" && "${ARCH}" != "arm64" ]]; then
  echo "[WARN] Скрипт рассчитан на aarch64, обнаружено: ${ARCH}" >&2
fi

log "Обновляю индекс пакетов..."
sudo apt update

log "Устанавливаю зависимости..."
sudo apt install -y \
  python3 \
  python3-pil \
  build-essential \
  g++ \
  make \
  v4l-utils

log "Готово. Этот скрипт только устанавливает зависимости и ничего не запускает."
