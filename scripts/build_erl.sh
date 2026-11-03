#!/usr/bin/env bash
# Compile erl/<name>.erl into the application pack build/erl/<name>.avm, precompiled for
# riscv32 (EMU=1: BEAM only). The library pack lives in the SPI flash (scripts/flash.sh lib).
# usage: [EMU=1] scripts/build_erl.sh [name]   (default hello)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
NAME="${1:-hello}"
OUT="$ROOT/build/erl"
mkdir -p "$OUT/riscv32"
erlc -o "$OUT" "$ROOT/erl/$NAME.erl"
BEAM="$OUT/$NAME.beam"
if [ "${EMU:-0}" != 1 ]; then
    erl -pa "$HOST_DIR/libs/jit/src/beams" -noshell -s jit_precompile -s init stop \
        -- riscv32 "$OUT/riscv32/" "$BEAM"
    BEAM="$OUT/riscv32/$NAME.beam"
fi
"$HOST_DIR/tools/packbeam/packbeam" create -s "$NAME" "$OUT/$NAME.avm" "$BEAM"
ls -l "$OUT/$NAME.avm"
