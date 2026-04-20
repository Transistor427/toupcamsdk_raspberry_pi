#!/usr/bin/env bash
set -euo pipefail

# Toupcam SDK installer for Raspberry Pi CM4 (Debian 12).
# Default SDK location is /home/pi/toupcamsdk, can be overridden by first arg.

SDK_DIR="${1:-/home/pi/toupcamsdk}"
RULES_SRC="${SDK_DIR}/linux/udev/99-toupcam.rules"
DEMO_DIR="${SDK_DIR}/samples/demosimplest"
PY_DIR="${SDK_DIR}/python"

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

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Команда '$1' не найдена"
}

if [[ ! -d "${SDK_DIR}" ]]; then
  if [[ -d "/home/pi/toupcamsdk_raspberry_pi" ]]; then
    warn "Папка ${SDK_DIR} не найдена, использую /home/pi/toupcamsdk_raspberry_pi"
    SDK_DIR="/home/pi/toupcamsdk_raspberry_pi"
    RULES_SRC="${SDK_DIR}/linux/udev/99-toupcam.rules"
    DEMO_DIR="${SDK_DIR}/samples/demosimplest"
    PY_DIR="${SDK_DIR}/python"
  else
    die "Не найдена папка SDK: ${SDK_DIR}"
  fi
fi

require_cmd uname
require_cmd file
require_cmd sudo
require_cmd cp
require_cmd bash

ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
if [[ -z "${ARCH}" ]]; then
  ARCH="$(uname -m)"
fi

LIB_ARCH_DIR=""
case "${ARCH}" in
  arm64|aarch64)
    LIB_ARCH_DIR="arm64"
    ;;
  armhf|armv7l|armv8l)
    LIB_ARCH_DIR="armhf"
    ;;
  *)
    die "Неподдерживаемая архитектура '${ARCH}'. Нужна arm64 или armhf."
    ;;
esac

LIB_SRC="${SDK_DIR}/linux/${LIB_ARCH_DIR}/libtoupcam.so"
[[ -f "${LIB_SRC}" ]] || die "Не найден файл библиотеки: ${LIB_SRC}"
[[ -f "${RULES_SRC}" ]] || die "Не найден файл udev rules: ${RULES_SRC}"
[[ -d "${DEMO_DIR}" ]] || die "Не найдена папка демо: ${DEMO_DIR}"
[[ -f "${SDK_DIR}/inc/toupcam.h" ]] || die "Не найден заголовок: ${SDK_DIR}/inc/toupcam.h"

log "SDK_DIR=${SDK_DIR}"
log "ARCH=${ARCH}, выбрана библиотека linux/${LIB_ARCH_DIR}/libtoupcam.so"

log "Устанавливаю необходимые пакеты..."
sudo apt update
sudo apt install -y build-essential g++ make python3

log "Устанавливаю udev rules..."
sudo cp "${RULES_SRC}" /etc/udev/rules.d/99-toupcam.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
log "udev rules применены. Если камера уже подключена, переподключите USB."

log "Устанавливаю libtoupcam.so в системный путь..."
sudo cp "${LIB_SRC}" /usr/local/lib/libtoupcam.so
sudo ldconfig

log "Готовлю C++ smoke-test (demosimplest)..."
cp "${SDK_DIR}/inc/toupcam.h" "${DEMO_DIR}/toupcam.h"
cp "${LIB_SRC}" "${DEMO_DIR}/libtoupcam.so"

pushd "${DEMO_DIR}" >/dev/null
bash make.sh
log "Запускаю demosimplest (Ctrl+C для остановки)..."
./demosimplest || warn "demosimplest завершился с ошибкой"
popd >/dev/null

if [[ -f "${PY_DIR}/samples/simplest.py" ]]; then
  log "Готовлю Python smoke-test..."
  cp "${LIB_SRC}" "${PY_DIR}/libtoupcam.so"
  log "Запуск: cd ${PY_DIR} && python3 samples/simplest.py"
else
  warn "Python sample не найден, пропускаю Python smoke-test"
fi

echo
log "Готово."
log "Если видите E_ACCESSDENIED, убедитесь, что камера переподключена после установки rules."
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_ROOT="$SCRIPT_DIR"

INSTALL_DEPS=1
SKIP_UDEV=0
SKIP_TEST=0
ASSUME_YES=0

usage() {
  cat <<'EOF'
Toupcam SDK installer for Raspberry Pi CM4 (Debian 12)

Usage:
  ./install_toupcam_cm4.sh [options]

Options:
  --skip-deps      Do not install apt packages
  --skip-udev      Do not install/reload udev rules
  --skip-test      Do not build/run demosimplest smoke test
  -y, --yes        Non-interactive apt install
  -h, --help       Show this help
EOF
}

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

err() {
  printf '[ERR ] %s\n' "$*" >&2
}

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    err "Required file not found: $f"
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-deps)
      INSTALL_DEPS=0
      shift
      ;;
    --skip-udev)
      SKIP_UDEV=1
      shift
      ;;
    --skip-test)
      SKIP_TEST=1
      shift
      ;;
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$SDK_ROOT/linux" || ! -d "$SDK_ROOT/samples" || ! -d "$SDK_ROOT/inc" ]]; then
  err "Run this script from SDK root (or keep it inside SDK root)."
  exit 1
fi

ARCH="$(uname -m)"
LIB_SRC=""
case "$ARCH" in
  aarch64|arm64)
    LIB_SRC="$SDK_ROOT/linux/arm64/libtoupcam.so"
    LIB_ARCH="arm64"
    ;;
  armv7l|armv6l|armhf)
    LIB_SRC="$SDK_ROOT/linux/armhf/libtoupcam.so"
    LIB_ARCH="armhf"
    ;;
  *)
    err "Unsupported architecture: $ARCH"
    err "Supported by this script: aarch64/arm64 and armv7l/armhf."
    exit 1
    ;;
esac

require_file "$LIB_SRC"
require_file "$SDK_ROOT/inc/toupcam.h"
require_file "$SDK_ROOT/linux/udev/99-toupcam.rules"
require_file "$SDK_ROOT/samples/demosimplest/demosimplest.cpp"
require_file "$SDK_ROOT/samples/demosimplest/make.sh"

log "Detected architecture: $ARCH"
log "Using library: $LIB_SRC"

if [[ "$INSTALL_DEPS" -eq 1 ]]; then
  log "Installing build dependencies..."
  APT_FLAGS=()
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    APT_FLAGS+=("-y")
  fi
  sudo apt-get update
  sudo apt-get install "${APT_FLAGS[@]}" build-essential g++ make python3
fi

if [[ "$SKIP_UDEV" -eq 0 ]]; then
  log "Installing udev rule for Toupcam USB devices..."
  sudo cp "$SDK_ROOT/linux/udev/99-toupcam.rules" /etc/udev/rules.d/99-toupcam.rules
  sudo udevadm control --reload-rules && sudo udevadm trigger
  log "udev rules reloaded. Replug camera USB cable if it was already connected."
else
  warn "Skipping udev setup."
fi

DEMO_DIR="$SDK_ROOT/samples/demosimplest"
log "Preparing demosimplest files..."
cp "$SDK_ROOT/inc/toupcam.h" "$DEMO_DIR/toupcam.h"
cp "$LIB_SRC" "$DEMO_DIR/libtoupcam.so"

if [[ "$SKIP_TEST" -eq 0 ]]; then
  log "Building demosimplest..."
  (
    cd "$DEMO_DIR"
    bash ./make.sh
  )

  log "Running demosimplest smoke test..."
  log "If no camera is connected, this may print zero camera count."
  (
    cd "$DEMO_DIR"
    ./demosimplest || true
  )
else
  warn "Skipping smoke test build/run."
fi

cat <<EOF

Done.

Summary:
  SDK root:    $SDK_ROOT
  Architecture:$ARCH ($LIB_ARCH)
  Demo path:   $DEMO_DIR

Next commands (manual):
  cd "$DEMO_DIR"
  ./demosimplest

Python test (optional):
  cp "$LIB_SRC" "$SDK_ROOT/python/libtoupcam.so"
  cd "$SDK_ROOT/python"
  python3 samples/simplest.py

EOF
