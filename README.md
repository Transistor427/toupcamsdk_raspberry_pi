# Toupcam на Raspberry Pi (Debian 12): краткий запуск потока

Это инструкция по запуску видеопотока через SDK `libtoupcam.so`.

Используется скрипт:
- `python/samples/toupcam_mjpeg_server.py`

Он берет кадры из Toupcam SDK и отдает MJPEG-поток по HTTP.

## 1) Установка

### 1.1 Проверка архитектуры
```bash
uname -m
```
- `aarch64` -> использовать `linux/arm64/libtoupcam.so`
- `armv7l`/`armhf` -> использовать `linux/armhf/libtoupcam.so`

### 1.2 Установка пакетов
```bash
sudo apt update
sudo apt install -y python3 python3-pil
```

### 1.3 Подготовка `libtoupcam.so`
```bash
cd /home/pi/toupcamsdk_raspberry_pi/python
cp /home/pi/toupcamsdk_raspberry_pi/linux/arm64/libtoupcam.so ./libtoupcam.so
```

Для 32-bit системы используй:
```bash
cp /home/pi/toupcamsdk_raspberry_pi/linux/armhf/libtoupcam.so ./libtoupcam.so
```

## 2) Запуск потока

```bash
cd /home/pi/toupcamsdk_raspberry_pi/python
python3 samples/toupcam_mjpeg_server.py --host 0.0.0.0 --port 8081
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
WorkingDirectory=/home/pi/toupcamsdk_raspberry_pi/python
ExecStart=/usr/bin/python3 /home/pi/toupcamsdk_raspberry_pi/python/samples/toupcam_mjpeg_server.py --host 0.0.0.0 --port 8081
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

