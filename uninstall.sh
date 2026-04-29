#!/usr/bin/env bash
set -euo pipefail

### Uninstall only files installed from this repo (no packages/groups).

SDK_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PY_DIR="${SDK_DIR}/python"
LOCAL_LIB="${PY_DIR}/libtoupcam.so"
SYSTEM_LIB="/usr/local/lib/libtoupcam.so"
UDEV_RULE="/etc/udev/rules.d/99-toupcam.rules"

log() {
  echo "[INFO] $*"
}

remove_file_if_exists() {
  local path="$1"
  if [[ -e "${path}" ]]; then
    log "Удаляю ${path}"
    sudo rm -f "${path}"
  else
    log "Файл не найден, пропускаю: ${path}"
  fi
}

log "Начинаю uninstall Toupcam setup (files only)..."

if [[ -e "${LOCAL_LIB}" ]]; then
  log "Удаляю локальную библиотеку: ${LOCAL_LIB}"
  rm -f "${LOCAL_LIB}"
else
  log "Локальная библиотека не найдена, пропускаю: ${LOCAL_LIB}"
fi

remove_file_if_exists "${SYSTEM_LIB}"
remove_file_if_exists "${UDEV_RULE}"

log "Обновляю кэш библиотек..."
sudo ldconfig

log "Перезагружаю udev-правила..."
sudo udevadm control --reload-rules
sudo udevadm trigger

cat <<EOF

[INFO] Uninstall завершен.

Удалено (если существовало):
  - ${LOCAL_LIB}
  - ${SYSTEM_LIB}
  - ${UDEV_RULE}

EOF
