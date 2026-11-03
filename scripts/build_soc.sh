#!/usr/bin/env bash
# Build the SoC gateware (gateware/soc.py) into build/soc/. Extra args go to LiteX.
# Prints the resource summary and Fmax.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
require_gowin
python3 "$ROOT/gateware/soc.py" --build --output-dir "$SOC_DIR" "$@"
"$ROOT/scripts/report.sh" "$SOC_DIR"
