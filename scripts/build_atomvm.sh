#!/usr/bin/env bash
# Build AtomVM for the SoC (apps/atomvm) -> $ATOMVM_BUILD_DIR/zephyr/AtomVM.bin
# (default build/app_atomvm). -DAVM_EXTRA_SOURCES="a.c;b.c" adds NIFs from elsewhere.
# usage: scripts/build_atomvm.sh [extra west build args]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
"$ROOT/scripts/gen_zephyr_overlay.sh" "$ROOT/build/overlay/atomvm.overlay" > /dev/null
source "$ZEPHYR_WORKSPACE/.venv/bin/activate"
export ZEPHYR_BASE="$ZEPHYR_WORKSPACE/zephyr" ATOMVM_DIR
# -p always: board.overlay / Kconfig changes must regenerate .config (CONFIG_SRAM_SIZE)
west build -b litex_vexriscv -d "$ATOMVM_BUILD_DIR" "$ROOT/apps/atomvm" -p always \
    -- -DDTC_OVERLAY_FILE="$ROOT/build/overlay/atomvm.overlay;$ROOT/apps/atomvm/board.overlay" "$@"
