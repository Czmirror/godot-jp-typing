#!/bin/sh
# このaddon単体で回帰試験を実行する。一時フォルダに最小のGodotプロジェクトを作り、
# addons/typing_core として複製し、TypingEngineをAutoload登録して両方の試験を走らせる。
# 使い方: GODOT=/path/to/godot sh tests/run_tests.sh
set -eu

GODOT="${GODOT:-godot}"
ADDON_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST_DIR="$(mktemp -d)"
trap 'rm -rf "$HOST_DIR"' EXIT

mkdir -p "$HOST_DIR/addons/typing_core"
# .gitなどの隠しファイルは複製しない
(cd "$ADDON_DIR" && tar cf - --exclude='./.*' .) | (cd "$HOST_DIR/addons/typing_core" && tar xf -)
cat > "$HOST_DIR/project.godot" <<'EOF'
config_version=5

[application]
config/name="typing_core_tests"

[autoload]
TypingEngine="*res://addons/typing_core/TypingEngine.gd"
EOF

# 初回はscriptのclass・uidの登録が必要なため、先にimportだけ行う
"$GODOT" --headless --path "$HOST_DIR" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$HOST_DIR" --script res://addons/typing_core/tests/run_romaji_converter_tests.gd
"$GODOT" --headless --path "$HOST_DIR" --script res://addons/typing_core/tests/run_typing_core_tests.gd
