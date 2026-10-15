#!/usr/bin/env bash
# CI (macOS): export dự án Xcode cho iOS, build cho iOS Simulator rồi chạy thử (chụp màn hình, đọc log), và build bản
# cho iPhone thật CHƯA KÝ, đóng gói thành build/ios/NeonHarbor-unsigned.ipa (ký + cài bằng xtool hoặc công cụ khác).
# Dùng: tools/ci/ios_build.sh <file chạy Godot>
set -euo pipefail
GODOT=$1
cd "$(dirname "$0")/../.."
OUT=build/ios
BUNDLE=com.neonharbor.game
mkdir -p "$OUT"
"$GODOT" --headless --path game --export-release "iOS" "../$OUT/NeonHarbor.xcodeproj" 2>&1 | grep -E "ERROR|WARNING" || true
[ -d "$OUT/NeonHarbor.xcodeproj" ] || { echo "FAIL: không export được dự án Xcode"; exit 1; }

nosign=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="")

echo "== Build cho iOS Simulator"
# Thư viện Godot cho Simulator chỉ có x86_64: build x86_64, Simulator trên máy chip Apple chạy qua Rosetta.
xcodebuild -project "$OUT/NeonHarbor.xcodeproj" -scheme NeonHarbor -configuration Debug -sdk iphonesimulator \
  -derivedDataPath "$OUT/dd-sim" ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO "${nosign[@]}" build -quiet
APP_SIM=$(find "$OUT/dd-sim/Build/Products" -maxdepth 2 -name "NeonHarbor.app" -type d | head -1)
[ -n "$APP_SIM" ] || { echo "FAIL: không có NeonHarbor.app cho Simulator"; exit 1; }

echo "== Chạy trong iOS Simulator"
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devs = json.load(sys.stdin)["devices"]
for runtime in sorted(devs, reverse=True):
    if "iOS" in runtime:
        for d in devs[runtime]:
            if d["name"].startswith("iPhone"):
                print(d["udid"]); raise SystemExit
')
[ -n "$UDID" ] || { echo "FAIL: không có máy ảo iPhone nào"; exit 1; }
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP_SIM"
xcrun simctl launch "$UDID" "$BUNDLE"
sleep 45
xcrun simctl io "$UDID" screenshot "$OUT/ios_simulator.png"
LOG=$(xcrun simctl spawn "$UDID" log show --last 2m --style compact --predicate 'process == "NeonHarbor"' 2>/dev/null || true)
echo "$LOG" | grep -E "SCRIPT ERROR|ERROR:" | head -20 || true
RUNNING=$(xcrun simctl spawn "$UDID" launchctl list | grep -c "$BUNDLE" || true)
xcrun simctl shutdown "$UDID" || true
if [ "$RUNNING" -eq 0 ]; then echo "FAIL: game không còn chạy sau 45 giây trong Simulator (có thể đã crash)"; exit 1; fi
if echo "$LOG" | grep -q "SCRIPT ERROR"; then echo "FAIL: có lỗi script khi chạy trong Simulator"; exit 1; fi
echo "PASS: game chạy trong iOS Simulator 45 giây, không lỗi script (ảnh: $OUT/ios_simulator.png)"

echo "== Build cho iPhone thật (chưa ký)"
xcodebuild -project "$OUT/NeonHarbor.xcodeproj" -scheme NeonHarbor -configuration Release -sdk iphoneos \
  -derivedDataPath "$OUT/dd-device" "${nosign[@]}" build -quiet
APP_DEV=$(find "$OUT/dd-device/Build/Products" -maxdepth 2 -name "NeonHarbor.app" -type d | head -1)
[ -n "$APP_DEV" ] || { echo "FAIL: không có NeonHarbor.app cho iPhone"; exit 1; }
rm -rf "$OUT/Payload" && mkdir "$OUT/Payload" && cp -R "$APP_DEV" "$OUT/Payload/"
(cd "$OUT" && zip -qry NeonHarbor-unsigned.ipa Payload)
echo "PASS: $OUT/NeonHarbor-unsigned.ipa ($(du -h "$OUT/NeonHarbor-unsigned.ipa" | cut -f1))"
