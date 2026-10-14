#!/usr/bin/env bash
# Phục vụ bản Web tại http://localhost:8060 (bản Web không bật thread nên không cần header COOP/COEP).
cd "$(dirname "$0")"
PORT=${PORT:-8060}
echo "Mở trình duyệt: http://localhost:$PORT"
exec python3 -m http.server "$PORT" -d build/web
