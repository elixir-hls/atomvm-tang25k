#!/usr/bin/env bash
# Load build/soc's bitstream to FPGA SRAM and serial-boot a Zephyr app, non-interactively; the
# console output is shown for SECONDS_RUN (default 10) and saved to build/run_<name>.log.
#   scripts/run.sh [name]          apps/<name> (default hello_world)
#   scripts/run.sh atomvm <erl>    build/erl/<erl>.avm (built here) into the staging slot, then
#                                  AtomVM boots from the SPI flash (scripts/flash.sh vm lib)
# The loader (litex_term under `script`, it needs a TTY; or scripts/load_app.py) starts first;
# loading the bitstream resets the FPGA and the BIOS then requests the serial boot.
# usage: [UART_PORT=/dev/ttyUSB1] [SECONDS_RUN=10] scripts/run.sh [name] [erl]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
NAME="${1:-hello_world}"
ERL="${2:-}"
BIN="$ROOT/build/app_$NAME/zephyr/zephyr.bin"
[ -e "$BIN" ] || BIN="$ROOT/build/app_$NAME/zephyr/AtomVM.bin"     # apps/atomvm names its image AtomVM
LOG="$ROOT/build/run_$NAME${ERL:+_$ERL}.log"
[ -e "$UART_PORT" ] || { echo "no $UART_PORT (is the ftdi_sio driver loaded?)"; exit 1; }
if [ -n "$ERL" ]; then
    "$ROOT/scripts/build_erl.sh" "$ERL" > /dev/null || exit 1
    : > "$LOG"
    python3 "$ROOT/scripts/load_app.py" "$UART_PORT" "$ROOT/build/erl/$ERL.avm" \
        --seconds "${SECONDS_RUN:-10}" --log "$LOG" > /dev/null &
    LOADER_PID=$!
    sleep 1
    openFPGALoader --cable ft2232 --bitstream "$BITSTREAM" > /dev/null 2>&1 || echo "openFPGALoader failed"
    wait "$LOADER_PID"
    sed -n '/load_app/,$p' "$LOG" | tr -d '\r'
    exit
fi
: > "$LOG"
script -qfc "litex_term $UART_PORT --kernel $BIN" "$LOG" > /dev/null 2>&1 &
TERM_PID=$!
sleep 1
openFPGALoader --cable ft2232 --bitstream "$BITSTREAM" > /dev/null 2>&1 || echo "openFPGALoader failed"
sleep "${SECONDS_RUN:-10}"
kill "$TERM_PID" 2> /dev/null; pkill -P "$TERM_PID" 2> /dev/null
strings -n 2 "$LOG" | sed -n '/Liftoff/,$p'
