#!/usr/bin/env bash
set -euo pipefail

# Auto-prepare Toupcam runtime files for Raspberry Pi (arm64/armhf).

SDK_DIR="${1:-/home/pi/toupcamsdk_raspberry_pi}"
PY_DIR="${SDK_DIR}/python"

log() {
  echo "[INFO] $*"
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

[[ -d "${SDK_DIR}" ]] || die "Не найдена папка SDK: ${SDK_DIR}"
[[ -d "${PY_DIR}" ]] || die "Не найдена папка: ${PY_DIR}"

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "${ARCH}" in
  arm64|aarch64)
    LIB_SRC="${SDK_DIR}/linux/arm64/libtoupcam.so"
    LIB_KIND="arm64"
    ;;
  armhf|armv7l|armv8l|armv6l)
    LIB_SRC="${SDK_DIR}/linux/armhf/libtoupcam.so"
    LIB_KIND="armhf"
    ;;
  *)
    die "Неподдерживаемая архитектура: ${ARCH}. Ожидается arm64 или armhf."
    ;;
esac

[[ -f "${LIB_SRC}" ]] || die "Не найден файл библиотеки: ${LIB_SRC}"
log "Архитектура: ${ARCH} -> использую ${LIB_KIND}"

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
