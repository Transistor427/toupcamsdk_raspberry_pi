#!/usr/bin/env bash
set -euo pipefail

# Auto-prepare Toupcam runtime files for Raspberry Pi aarch64.

SDK_DIR="${1:-/home/pi/toupcamsdk_raspberry_pi}"

PY_DIR="${SDK_DIR}/python"
LIB_SRC="${SDK_DIR}/linux/arm64/libtoupcam.so"

log() {
  echo "[INFO] $*"
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

[[ -d "${SDK_DIR}" ]] || die "Не найдена папка SDK: ${SDK_DIR}"
[[ -f "${LIB_SRC}" ]] || die "Не найден файл: ${LIB_SRC}"
[[ -d "${PY_DIR}" ]] || die "Не найдена папка: ${PY_DIR}"

ARCH="$(uname -m)"
if [[ "${ARCH}" != "aarch64" && "${ARCH}" != "arm64" ]]; then
  die "Скрипт для aarch64, а текущая архитектура: ${ARCH}"
fi

log "Копирую libtoupcam.so в python/"
cp "${LIB_SRC}" "${PY_DIR}/libtoupcam.so"

log "Обновляю системный путь библиотеки"
sudo cp "${LIB_SRC}" /usr/local/lib/libtoupcam.so
sudo ldconfig

cat <<EOF

Готово.

Подготовлено:
  - ${PY_DIR}/libtoupcam.so
  - /usr/local/lib/libtoupcam.so

Дальше можно запускать:
  cd ${PY_DIR}
  python3 samples/toupcam_mjpeg_server.py --host 0.0.0.0 --port 8081 --width 1280 --height 720 --bandwidth 60

EOF
