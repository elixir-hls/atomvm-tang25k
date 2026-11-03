# Common environment for the scripts (sourced).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LITEX_DEPS="${LITEX_DEPS:-$ROOT/deps}"          # pinned LiteX workspace (scripts/setup_litex.sh)
# Gowin IDE (gw_sh, which LiteX runs to build the gateware): GOWIN_HOME is the directory it
# is installed in (developed with Gowin V1.9.11.03 Education); the scripts that build a SoC
# stop without it (require_gowin)
if [ -n "${GOWIN_HOME:-}" ]; then
    export PATH="$GOWIN_HOME/IDE/bin:$PATH"
fi
require_gowin() {
    if [ -z "${GOWIN_HOME:-}" ]; then
        echo "GOWIN_HOME is not set: the directory the Gowin IDE is installed in" >&2
        echo "  (e.g. export GOWIN_HOME=\$HOME/Gowin_V1.9.11.03_Education in the shell profile)" >&2
        exit 1
    fi
    if [ ! -x "$GOWIN_HOME/IDE/bin/gw_sh" ]; then
        echo "GOWIN_HOME=$GOWIN_HOME: no IDE/bin/gw_sh there (the Gowin IDE's directory?)" >&2
        exit 1
    fi
}
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"   # gw_sh starts Qt; no X display needed
# SOC_DIR / ATOMVM_BUILD_DIR may be set by a repository that extends this one
SOC_DIR="${SOC_DIR:-$ROOT/build/soc}"
CSR_JSON="$SOC_DIR/csr.json"
BITSTREAM="$SOC_DIR/gateware/sipeed_tang_primer_25k.fs"
ZEPHYR_WORKSPACE="${ZEPHYR_WORKSPACE:-$HOME/zephyrproject}"
UART_PORT="${UART_PORT:-/dev/ttyUSB1}"
ATOMVM_DIR="${ATOMVM_DIR:-$ROOT/ext/AtomVM}"
HOST_DIR="$ROOT/build/host"
ATOMVM_BUILD_DIR="${ATOMVM_BUILD_DIR:-$ROOT/build/app_atomvm}"
