# Toupcam на Raspberry Pi (Debian 12): краткий запуск потока

Это инструкция по запуску видеопотока через SDK `libtoupcam.so`.

Используется скрипт:
- `python/samples/toupcam_mjpeg_server.py`

Он берет кадры из Toupcam SDK и отдает MJPEG-поток по HTTP.

## 1) Установка (только зависимости)

### 1.1 Проверка архитектуры
```bash
uname -m
```
- `aarch64` -> использовать `linux/arm64/libtoupcam.so`
- `armv7l`/`armhf` -> использовать `linux/armhf/libtoupcam.so`

### 1.2 Запуск установочного скрипта
```bash
cd /home/pi/toupcamsdk_raspberry_pi
chmod +x install_toupcam_cm4.sh
./install_toupcam_cm4.sh
```

Скрипт `install_toupcam_cm4.sh` только ставит пакеты и ничего не запускает.

## 2) Запуск потока

Запуск одним скриптом:
```bash
cd /home/pi/toupcamsdk_raspberry_pi
chmod +x run_toupcam_stream.sh
./run_toupcam_stream.sh
```

Опционально с параметрами:
```bash
./run_toupcam_stream.sh /home/pi/toupcamsdk_raspberry_pi 0.0.0.0 8081 1280 720 60
```

Если видишь ошибку `cannot open shared object file` или `wrong ELF class`, выполни:
```bash
cd /home/pi/toupcamsdk_raspberry_pi
./prepare_runtime_aarch64.sh
dpkg --print-architecture
ls -l /home/pi/toupcamsdk_raspberry_pi/python/libtoupcam.so
```
и затем снова:
```bash
./run_toupcam_stream.sh
```

## 3) Проверка

- Превью-страница: `http://<IP_RPI>:8081/`
- Поток MJPEG: `http://<IP_RPI>:8081/stream`
- Статус: `http://<IP_RPI>:8081/health`

Если страница не открывается:
- проверь, что процесс запущен;
- проверь порт `8081` (`ss -lntp | grep 8081`);
- проверь сеть между ПК и Raspberry Pi.

## 4) Запуск в фоне через systemd (опционально)

Создай сервис:
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

Включение и запуск:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now toupcam-mjpeg.service
```

Проверка логов:
```bash
journalctl -u toupcam-mjpeg.service -f
```

## 5) URL для использования в приложениях

Используй поток по адресу:
- `http://127.0.0.1:8081/stream` (на самой Raspberry Pi)
- `http://<IP_RPI>:8081/stream` (с другого устройства в сети)

Одиночный снимок (JPEG):
- `http://127.0.0.1:8081/snapshot.jpg`

## 6) Кадр по команде из Klipper (TOUPTEK_TAKE_FRAME)

### 6.1 Подготовка скрипта снимка
```bash
cd /home/pi/toupcamsdk_raspberry_pi
chmod +x klipper_take_frame.sh
```

Проверка вручную:
```bash
./klipper_take_frame.sh
```

### 6.2 Макрос в `printer.cfg`
Добавь:
```ini
[gcode_shell_command touptek_take_frame]
command: /bin/bash /home/pi/toupcamsdk_raspberry_pi/klipper_take_frame.sh /home/pi/printer_data/timelapse/toupcam
timeout: 10.
verbose: False

[gcode_macro TOUPTEK_TAKE_FRAME]
description: Save one frame from Toupcam MJPEG bridge
gcode:
    RUN_SHELL_COMMAND CMD=touptek_take_frame
```

После изменения:
```bash
sudo systemctl restart klipper
```

Теперь можно вызывать в G-code:
```gcode
TOUPTEK_TAKE_FRAME
```

