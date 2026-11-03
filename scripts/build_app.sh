#!/usr/bin/env bash
# Build the Zephyr app apps/<name> (default hello_world) against the current build/soc/csr.json.
# usage: scripts/build_app.sh [name] [extra west build args]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
NAME="${1:-hello_world}"; shift || true
APP="$ROOT/apps/$NAME"
"$ROOT/scripts/gen_zephyr_overlay.sh" "$ROOT/build/overlay/$NAME.overlay" > /dev/null
source "$ZEPHYR_WORKSPACE/.venv/bin/activate"
export ZEPHYR_BASE="$ZEPHYR_WORKSPACE/zephyr"
west build -b litex_vexriscv -d "$ROOT/build/app_$NAME" "$APP" -p auto \
    -- -DDTC_OVERLAY_FILE="$ROOT/build/overlay/$NAME.overlay" "$@"
