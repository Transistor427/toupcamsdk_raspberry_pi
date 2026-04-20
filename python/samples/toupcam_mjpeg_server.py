#!/usr/bin/env python3
import argparse
import io
import pathlib
import sys
import threading
import time
from http import server
from socketserver import ThreadingMixIn

from PIL import Image

# Allow running directly from python/samples while importing ../toupcam.py
THIS_DIR = pathlib.Path(__file__).resolve().parent
PY_ROOT = THIS_DIR.parent
if str(PY_ROOT) not in sys.path:
    sys.path.insert(0, str(PY_ROOT))

import toupcam


class CameraState:
    def __init__(self):
        self.lock = threading.Lock()
        self.jpeg = None
        self.frames = 0
        self.last_error = None


class ToupcamMjpegBridge:
    def __init__(self, width, height, jpeg_quality, bandwidth):
        self.width_req = width
        self.height_req = height
        self.jpeg_quality = jpeg_quality
        self.bandwidth = bandwidth
        self.state = CameraState()
        self.cam = None
        self.buf = None
        self.width = 0
        self.height = 0

    @staticmethod
    def _on_event(nEvent, ctx):
        if nEvent == toupcam.TOUPCAM_EVENT_IMAGE:
            ctx._on_image()

    def _encode_jpeg(self, rgb_bytes):
        image = Image.frombytes("RGB", (self.width, self.height), rgb_bytes)
        out = io.BytesIO()
        image.save(out, format="JPEG", quality=self.jpeg_quality, optimize=True)
        return out.getvalue()

    def _on_image(self):
        try:
            self.cam.PullImageV4(self.buf, 0, 24, 0, None)
            jpeg = self._encode_jpeg(self.buf)
            with self.state.lock:
                self.state.jpeg = jpeg
                self.state.frames += 1
        except Exception as ex:  # noqa: BLE001
            with self.state.lock:
                self.state.last_error = str(ex)

    def open(self):
        cams = toupcam.Toupcam.EnumV2()
        if not cams:
            raise RuntimeError("Камера не найдена через Toupcam SDK")

        self.cam = toupcam.Toupcam.Open(cams[0].id)
        if self.cam is None:
            raise RuntimeError("Не удалось открыть камеру")

        if self.width_req > 0 and self.height_req > 0:
            try:
                self.cam.put_Size(self.width_req, self.height_req)
            except toupcam.HRESULTException as ex:
                hr = ex.hr & 0xFFFFFFFF
                if hr == toupcam.E_INVALIDARG:
                    supported = []
                    for r in cams[0].model.res:
                        if r.width > 0 and r.height > 0:
                            supported.append(f"{r.width}x{r.height}")
                    print(
                        "[WARN] Запрошенное разрешение "
                        f"{self.width_req}x{self.height_req} не поддерживается. "
                        "Использую нативное разрешение камеры."
                    )
                    if supported:
                        print(f"[INFO] Поддерживаемые разрешения: {', '.join(supported)}")
                else:
                    raise RuntimeError(
                        f"Ошибка установки разрешения, HRESULT=0x{hr:08x}"
                    ) from ex

        self.width, self.height = self.cam.get_Size()
        self.cam.put_Option(toupcam.TOUPCAM_OPTION_BYTEORDER, 0)  # RGB
        if self.bandwidth > 0:
            # Lower USB bandwidth can improve stability on weak USB/power setups.
            self.cam.put_Option(toupcam.TOUPCAM_OPTION_BANDWIDTH, self.bandwidth)

        bufsize = toupcam.TDIBWIDTHBYTES(self.width * 24) * self.height
        self.buf = bytes(bufsize)

        try:
            self.cam.StartPullModeWithCallback(ToupcamMjpegBridge._on_event, self)
        except toupcam.HRESULTException as ex:
            hr = ex.hr & 0xFFFFFFFF
            if hr == toupcam.E_GEN_FAILURE:
                raise RuntimeError(
                    "Не удалось запустить поток: E_GEN_FAILURE (0x8007001f). "
                    "Обычно это нестабильный USB (кабель/порт/питание) или устройство уже занято."
                ) from ex
            if hr == toupcam.E_BUSY:
                raise RuntimeError(
                    "Не удалось запустить поток: E_BUSY. Камера уже используется другим процессом."
                ) from ex
            raise RuntimeError(f"Не удалось запустить поток, HRESULT=0x{hr:08x}") from ex
        print(f"[INFO] Camera started: {self.width}x{self.height}")

    def close(self):
        if self.cam is not None:
            self.cam.Close()
            self.cam = None


class ThreadedHttpServer(ThreadingMixIn, server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class MjpegHandler(server.BaseHTTPRequestHandler):
    bridge = None

    def do_GET(self):  # noqa: N802
        if self.path in ("/", "/index.html"):
            self._serve_index()
            return
        if self.path.startswith("/stream"):
            self._serve_stream()
            return
        if self.path.startswith("/health"):
            self._serve_health()
            return

        self.send_error(404, "Not found")

    def _serve_index(self):
        body = (
            "<html><head><title>Toupcam MJPEG</title></head>"
            "<body><h3>Toupcam MJPEG bridge</h3>"
            "<p>Stream: <a href='/stream'>/stream</a></p>"
            "<img src='/stream' style='max-width: 100%; height: auto;'/>"
            "</body></html>"
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_health(self):
        with self.bridge.state.lock:
            frames = self.bridge.state.frames
            has_frame = self.bridge.state.jpeg is not None
            err = self.bridge.state.last_error
        body = (
            f'{{"ok": {str(has_frame).lower()}, "frames": {frames}, "error": "{err or ""}"}}'
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_stream(self):
        self.send_response(200)
        self.send_header("Age", "0")
        self.send_header("Cache-Control", "no-cache, private")
        self.send_header("Pragma", "no-cache")
        self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame")
        self.end_headers()

        try:
            while True:
                with self.bridge.state.lock:
                    jpeg = self.bridge.state.jpeg
                if jpeg is None:
                    time.sleep(0.03)
                    continue
                self.wfile.write(b"--frame\r\n")
                self.wfile.write(b"Content-Type: image/jpeg\r\n")
                self.wfile.write(f"Content-Length: {len(jpeg)}\r\n\r\n".encode("ascii"))
                self.wfile.write(jpeg)
                self.wfile.write(b"\r\n")
                time.sleep(0.001)
        except (BrokenPipeError, ConnectionResetError):
            return

    def log_message(self, fmt, *args):  # noqa: A003
        return


def parse_args():
    p = argparse.ArgumentParser(description="Toupcam to MJPEG HTTP bridge")
    p.add_argument("--host", default="0.0.0.0", help="HTTP bind host")
    p.add_argument("--port", type=int, default=8081, help="HTTP bind port")
    p.add_argument("--width", type=int, default=0, help="Requested width (0 = camera default)")
    p.add_argument("--height", type=int, default=0, help="Requested height (0 = camera default)")
    p.add_argument("--jpeg-quality", type=int, default=80, help="JPEG quality 1..95")
    p.add_argument(
        "--bandwidth",
        type=int,
        default=70,
        help="USB bandwidth 1..100 (lower = safer on weak USB), default: 70",
    )
    return p.parse_args()


def main():
    args = parse_args()

    bridge = ToupcamMjpegBridge(
        width=args.width,
        height=args.height,
        jpeg_quality=max(1, min(95, args.jpeg_quality)),
        bandwidth=max(1, min(100, args.bandwidth)),
    )
    bridge.open()

    MjpegHandler.bridge = bridge
    httpd = ThreadedHttpServer((args.host, args.port), MjpegHandler)
    print(f"[INFO] MJPEG URL: http://{args.host}:{args.port}/stream")
    print(f"[INFO] Health URL: http://{args.host}:{args.port}/health")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] Stopping...")
    finally:
        httpd.server_close()
        bridge.close()


if __name__ == "__main__":
    main()
