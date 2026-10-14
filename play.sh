#!/usr/bin/env bash
# Chạy bản export Linux; nếu chưa export thì chạy thẳng project bằng Godot.
cd "$(dirname "$0")"
BIN=build/linux/NeonHarbor.x86_64
if [ -x "$BIN" ]; then
  exec "$BIN" "$@"
fi
GODOT=${GODOT:-$(command -v godot || echo "$HOME/games/tools/godot/godot")}
exec "$GODOT" --path game "$@"
