#!/usr/bin/env bash
# Build AtomVM's host-side tools from the pinned checkout into build/host/: packbeam (needs
# rebar3), the JIT compiler (for precompiling), atomvmlib-zephyr.avm (BEAM), and
# atomvmlib-zephyr-native.avm: every module of it precompiled for riscv32.
# AtomVM's own riscv32 library pack leaves eavmlib, avm_zephyr, exavmlib... as BEAM, and
# calls between native and emulated code fail on this port (docs/design.md), so the library
# is precompiled module by module here.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cmake -S "$ATOMVM_DIR" -B "$HOST_DIR" -G Ninja -DAVM_DISABLE_JIT=ON \
    -DAVM_ENABLE_PRECOMPILED=ON -DAVM_PRECOMPILED_TARGETS=riscv32 > /dev/null
cmake --build "$HOST_DIR" --target PackBEAM atomvmlib-zephyr
W="$HOST_DIR/libs/native"
rm -rf "$W" && mkdir -p "$W/beam" "$W/riscv32"
"$HOST_DIR/tools/packbeam/packbeam" extract -o "$W/beam" "$HOST_DIR/libs/atomvmlib-zephyr.avm" > /dev/null
erl -pa "$HOST_DIR/libs/jit/src/beams" -noshell -s jit_precompile -s init stop \
    -- riscv32 "$W/riscv32/" "$W"/beam/*.beam
"$HOST_DIR/tools/packbeam/packbeam" create --lib "$HOST_DIR/libs/atomvmlib-zephyr-native.avm" \
    "$W"/riscv32/*.beam
ls -l "$HOST_DIR/tools/packbeam/packbeam" "$HOST_DIR"/libs/atomvmlib-zephyr*.avm
