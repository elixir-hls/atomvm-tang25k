#!/usr/bin/env bash
# Clone and install the pinned LiteX repositories (litex_repos.py) into deps/.
# An existing workspace at the same commits can be used instead: ln -s <workspace> deps
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
mkdir -p "$LITEX_DEPS"
cp "$ROOT/litex_setup.py" "$ROOT/litex_repos.py" "$LITEX_DEPS/"
cd "$LITEX_DEPS"
# --dev keeps litex_setup.py from fetching a newer litex_repos.py
python3 litex_setup.py --init --install --user --dev "$@"
