#!/usr/bin/env bash
set -euo pipefail

# Uninstall Toupcam runtime/setup created by install_toupcam_cm4.sh.
# By default removes files/rules only. Optional flags can remove packages/group membership.

SDK_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PURGE_DEPS=0
REMOVE_PLUGDEV=0
TARGET_USER="${SUDO_USER:-${USER}}"

for arg in "${@:2}"; do
  case "${arg}" in
    --purge-deps)
      PURGE_DEPS=1
      ;;
    --remove-plugdev)
      REMOVE_PLUGDEV=1
      ;;
    --user=*)
      TARGET_USER="${arg#--user=}"
      ;;
    *)
      echo "[WARN] Неизвестный аргумент: ${arg}" >&2
      ;;
  esac
done

PY_DIR="${SDK_DIR}/python"
LOCAL_LIB="${PY_DIR}/libtoupcam.so"
SYSTEM_LIB="/usr/local/lib/libtoupcam.so"
UDEV_RULE="/etc/udev/rules.d/99-toupcam.rules"

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
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

log "Начинаю uninstall Toupcam setup..."

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

if [[ "${REMOVE_PLUGDEV}" == "1" ]]; then
  if getent group plugdev >/dev/null 2>&1; then
    if id -u "${TARGET_USER}" >/dev/null 2>&1; then
      log "Удаляю пользователя ${TARGET_USER} из группы plugdev..."
      sudo gpasswd -d "${TARGET_USER}" plugdev || warn "Не удалось удалить из plugdev (возможно, пользователя там нет)."
      warn "Перелогиньтесь (или reboot), чтобы изменение группы вступило в силу."
    else
      warn "Пользователь не найден: ${TARGET_USER}"
    fi
  else
    log "Группа plugdev отсутствует, пропускаю."
  fi
fi

if [[ "${PURGE_DEPS}" == "1" ]]; then
  log "Удаляю пакеты зависимостей (purge)..."
  sudo apt purge -y \
    python3-pil \
    v4l-utils \
    build-essential \
    g++ \
    make || warn "Часть пакетов не удалось удалить."
  log "Очищаю неиспользуемые пакеты..."
  sudo apt autoremove -y || true
fi

cat <<EOF

[INFO] Uninstall завершен.

Удалено:
  - ${LOCAL_LIB} (если существовал)
  - ${SYSTEM_LIB} (если существовал)
  - ${UDEV_RULE} (если существовал)

Опции:
  --purge-deps       удалить зависимости, поставленные install-скриптом
  --remove-plugdev   удалить пользователя из группы plugdev
  --user=<name>      пользователь для --remove-plugdev

EOF
