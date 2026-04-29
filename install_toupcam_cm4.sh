#!/usr/bin/env bash
set -euo pipefail

# Full install/setup for Toupcam stream on Raspberry Pi.
# Includes dependencies, runtime library preparation, udev rules, and script permissions.

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_DIR="${1:-${SCRIPT_DIR}}"
PY_DIR="${SDK_DIR}/python"
UDEV_RULES_SRC="${SDK_DIR}/linux/udev/99-toupcam.rules"
PREPARE_SCRIPT="${SDK_DIR}/prepare_runtime_aarch64.sh"

ARCH="$(uname -m)"
if [[ "${ARCH}" != "aarch64" && "${ARCH}" != "arm64" ]]; then
  warn "Скрипт в первую очередь рассчитан на Raspberry Pi ARM, обнаружено: ${ARCH}"
fi

[[ -d "${SDK_DIR}" ]] || die "Не найдена папка SDK: ${SDK_DIR}"
[[ -d "${PY_DIR}" ]] || die "Не найдена папка python: ${PY_DIR}"
[[ -f "${PREPARE_SCRIPT}" ]] || die "Не найден скрипт: ${PREPARE_SCRIPT}"

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

log "Выставляю права на исполняемые скрипты..."
chmod +x \
  "${SDK_DIR}/install_toupcam_cm4.sh" \
  "${SDK_DIR}/prepare_runtime_aarch64.sh" \
  "${SDK_DIR}/run_toupcam_stream.sh" \
  "${SDK_DIR}/klipper_take_frame.sh"

log "Подготавливаю runtime-библиотеку libtoupcam.so..."
bash "${PREPARE_SCRIPT}" "${SDK_DIR}"

if [[ -f "${UDEV_RULES_SRC}" ]]; then
  log "Устанавливаю udev-правила для доступа к USB-камере..."
  sudo cp "${UDEV_RULES_SRC}" /etc/udev/rules.d/
  sudo udevadm control --reload-rules
  sudo udevadm trigger
else
  warn "Не найден файл udev-правил: ${UDEV_RULES_SRC}"
fi

if getent group plugdev >/dev/null 2>&1; then
  if id -nG "${USER}" | tr ' ' '\n' | while IFS= read -r grp; do [[ "${grp}" == "plugdev" ]] && exit 0; done; then
    log "Пользователь ${USER} уже состоит в группе plugdev."
  else
    log "Добавляю пользователя ${USER} в группу plugdev..."
    sudo usermod -aG plugdev "${USER}"
    warn "Требуется перелогиниться (или reboot), чтобы применить новую группу."
  fi
fi

cat <<EOF

[INFO] Готово.

Выполнено автоматически:
  - установка зависимостей
  - подготовка libtoupcam.so для текущей архитектуры
  - установка udev-правил Toupcam
  - права на исполняемые скрипты

Рекомендуется:
  1) Переподключить камеру Toupcam.
  2) Если менялась группа пользователя — перелогиниться или перезагрузить Raspberry Pi.

Запуск потока:
  cd ${SDK_DIR}
  ./run_toupcam_stream.sh

EOF
