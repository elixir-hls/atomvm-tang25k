#!/usr/bin/env bash
# Write to the Tang Primer 25K's SPI flash (W25Q64) over JTAG, for standalone boot and for
# scripts/run.sh's fast app loading. Layout (gateware/soc.py):
#   bitstream  0x000000  the SoC (build/soc)
#   vm         0x100000  AtomVM image ($ATOMVM_BUILD_DIR), BIOS flash boot format
#                        [length][CRC32 (zlib)][image], little-endian
#   lib        0x200000  library AVM pack: atomvmlib-zephyr-native.avm (all precompiled), or
#   lib-emu              atomvmlib-zephyr.avm (BEAM only, emulated)       (build/host/libs)
#   app <name> 0x600000  application AVM pack build/erl/<name>.avm (built here)
# usage: scripts/flash.sh [bitstream] [vm] [lib|lib-emu] [app <name>] | all <name>
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
[ $# -gt 0 ] || { sed -n 2,12p "$0"; exit 1; }
[ "$1" = all ] && set -- bitstream vm lib app "${2:?usage: $0 all <name>}"

write() {   # write <offset> <file>
    echo "== $(basename "$2") -> flash $1"
    openFPGALoader -b tangprimer25k -f --file-type bin -o "$1" --verify "$2"
}

while [ $# -gt 0 ]; do
    case "$1" in
    bitstream)
        echo "== bitstream -> flash 0x0"
        openFPGALoader -b tangprimer25k -f --skip-reset "$BITSTREAM" ;;
    vm)
        BIN="$ATOMVM_BUILD_DIR/zephyr/AtomVM.bin"
        IMG="$ATOMVM_BUILD_DIR/flash_vm.bin"
        python3 - "$BIN" "$IMG" << 'PY'
import struct, sys, zlib
data = open(sys.argv[1], "rb").read()
open(sys.argv[2], "wb").write(struct.pack("<II", len(data), zlib.crc32(data)) + data)
PY
        write 0x100000 "$IMG" ;;
    lib)
        write 0x200000 "$HOST_DIR/libs/atomvmlib-zephyr-native.avm" ;;
    lib-emu)
        write 0x200000 "$HOST_DIR/libs/atomvmlib-zephyr.avm" ;;
    app)
        "$ROOT/scripts/build_erl.sh" "$2" > /dev/null
        write 0x600000 "$ROOT/build/erl/$2.avm"
        shift ;;
    *)
        echo "unknown target $1"; exit 1 ;;
    esac
    shift
done
