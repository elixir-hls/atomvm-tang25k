#!/usr/bin/env bash
# Clone and install the pinned LiteX repositories (litex_repos.py) into deps/.
# An existing workspace at the same commits can be used instead: ln -s <workspace> deps
# --venv: install them into a virtual environment of their own, venv/ (python3 -m venv), and
# not into the user's site-packages; the builds then run LiteX with venv/bin/python3
# (LITEX_PYTHON, env.sh). mix ehls.setup sets the base up so, leaving the machine's Python alone.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
PY=python3
MODE=--user
if [ "${1:-}" = --venv ]; then
    shift
    [ -x "$ROOT/venv/bin/python3" ] || python3 -m venv "$ROOT/venv"
    PY="$ROOT/venv/bin/python3"
    MODE=
fi
mkdir -p "$LITEX_DEPS"
cp "$ROOT/litex_setup.py" "$ROOT/litex_repos.py" "$LITEX_DEPS/"
cd "$LITEX_DEPS"
# --dev keeps litex_setup.py from fetching a newer litex_repos.py
"$PY" litex_setup.py --init --install $MODE --dev "$@"
