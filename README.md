# Toupcam MJPEG на Raspberry Pi (Debian 12)

Пошаговая инструкция: клонируем репозиторий, ставим зависимости, запускаем MJPEG-поток с камеры Toupcam.

## 1) Клонирование

```bash
cd ~
git clone https://github.com/Transistor427/toupcamsdk_raspberry_pi toupcamsdk_raspberry_pi
cd ~/toupcamsdk_raspberry_pi
```

Если репозиторий уже скачан:

```bash
cd ~/toupcamsdk_raspberry_pi
git pull
```

## 2) Установка зависимостей

```bash
cd ~/toupcamsdk_raspberry_pi
chmod +x install_toupcam_cm4.sh
./install_toupcam_cm4.sh
```

Скрипт делает всё нужное автоматически:
- устанавливает зависимости;
- подготавливает `libtoupcam.so` под текущую архитектуру;
- устанавливает `udev`-правила для USB-доступа к камере;
- выставляет права на исполняемые скрипты.

После установки рекомендуется переподключить камеру (или перезагрузить Raspberry Pi).

## 3) Подготовка runtime `libtoupcam.so` (опционально, вручную)

Проверка архитектуры:

```bash
uname -m
```

- `aarch64` -> нужен `linux/arm64/libtoupcam.so`
- `armv7l`/`armhf` -> нужен `linux/armhf/libtoupcam.so`

Если нужно повторно/вручную подготовить runtime:

```bash
cd ~/toupcamsdk_raspberry_pi
chmod +x prepare_runtime_aarch64.sh
./prepare_runtime_aarch64.sh
```

Проверка:

```bash
dpkg --print-architecture
ls -l ~/toupcamsdk_raspberry_pi/python/libtoupcam.so
```

## 4) Настройка прав USB (опционально, вручную)

Обычно этот шаг уже выполнен через `install_toupcam_cm4.sh`.
Если видите `HRESULT=0x80070005 (E_ACCESSDENIED)`, можно повторить вручную:

```bash
cd ~/toupcamsdk_raspberry_pi
sudo cp linux/udev/99-toupcam.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

После этого переподключите камеру (или перезагрузите Raspberry Pi).

## 5) Запуск потока

Быстрый запуск:

```bash
cd ~/toupcamsdk_raspberry_pi
chmod +x run_toupcam_stream.sh
./run_toupcam_stream.sh
```

`run_toupcam_stream.sh` больше не делает полную подготовку при каждом старте:
- если `python/libtoupcam.so` уже есть, запуск идет сразу;
- если файла нет, prepare выполняется автоматически один раз.

Принудительно повторить prepare можно так:

```bash
FORCE_PREPARE=1 ./run_toupcam_stream.sh
```

Запуск с параметрами:

```bash
./run_toupcam_stream.sh ~/toupcamsdk_raspberry_pi 0.0.0.0 8081 1280 720 60
```

Где параметры:
- путь к проекту
- host
- port
- width
- height
- bandwidth

## 6) Проверка работы

Откройте в браузере:

- `http://<IP_RPI>:8081/` — страница превью
- `http://<IP_RPI>:8081/stream` — MJPEG поток
- `http://<IP_RPI>:8081/snapshot.jpg` — одиночный кадр
- `http://<IP_RPI>:8081/health` — статус

Если не открывается:

```bash
ss -lntp | grep 8081
```

Убедитесь, что процесс запущен и сеть между ПК и Raspberry Pi доступна.

## 7) Автозапуск через systemd (опционально)

Создайте сервис:

```bash
sudo tee /etc/systemd/system/toupcam-mjpeg.service >/dev/null <<'EOF'
[Unit]
Description=Toupcam MJPEG bridge
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/toupcamsdk_raspberry_pi
ExecStart=/bin/bash /home/pi/toupcamsdk_raspberry_pi/run_toupcam_stream.sh /home/pi/toupcamsdk_raspberry_pi 0.0.0.0 8081 1280 720 60
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
```

Включите и запустите:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now toupcam-mjpeg.service
```

Логи:

```bash
journalctl -u toupcam-mjpeg.service -f
```

## 8) Кадр из Klipper (TOUPTEK_TAKE_FRAME)

Подготовка:

```bash
cd ~/toupcamsdk_raspberry_pi
chmod +x klipper_take_frame.sh
./klipper_take_frame.sh
```

Добавьте в `printer.cfg`:

```ini
[gcode_shell_command touptek_take_frame]
command: /bin/bash /home/pi/toupcamsdk_raspberry_pi/klipper_take_frame.sh /home/pi/printer_data/config/FRAMES
timeout: 10.
verbose: False

[gcode_macro TOUPTEK_TAKE_FRAME]
description: Save one frame from Toupcam MJPEG bridge
gcode:
    RUN_SHELL_COMMAND CMD=touptek_take_frame
```

Применение:

```bash
sudo systemctl restart klipper
```

Дальше можно вызывать в G-code:

```gcode
TOUPTEK_TAKE_FRAME
```

## 9) Удаление (uninstall)

Базовый откат (то, что добавляла установка):

```bash
cd ~/toupcamsdk_raspberry_pi
chmod +x uninstall.sh
./uninstall.sh
```

Что удаляется:
- `python/libtoupcam.so`
- `/usr/local/lib/libtoupcam.so`
- `/etc/udev/rules.d/99-toupcam.rules`

Опционально:

```bash
./uninstall.sh ~/toupcamsdk_raspberry_pi --remove-plugdev
./uninstall.sh ~/toupcamsdk_raspberry_pi --purge-deps
```

