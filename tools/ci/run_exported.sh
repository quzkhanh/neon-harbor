#!/usr/bin/env bash
# CI: chạy bản game đã export ở chế độ không cửa sổ, vào thành phố với dân/xe tối đa + 5 sao + mưa (kịch bản perf),
# fail nếu không tới được dòng "PERF" hoặc có lỗi script. Dùng: tools/ci/run_exported.sh <file chạy>
set -uo pipefail
out=$(timeout 300 "$1" --headless -- --shot=perf 2>&1)
code=$?
echo "$out" | grep -E "PERF|SCRIPT ERROR|ERROR" | head -20
if [ $code -ne 0 ] || ! echo "$out" | grep -q "^PERF " || echo "$out" | grep -q "SCRIPT ERROR"; then
  echo "FAIL: bản export không chạy được tới thành phố (exit $code)"
  exit 1
fi
echo "PASS: bản export vào thành phố, chạy kịch bản 5 sao + mưa rồi thoát sạch"
