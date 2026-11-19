#!/usr/bin/env bash
# Fetch AtomVM with its Zephyr port (PR #2389, draft, from petermm/AtomVM's pr/958-rebased) at a
# pinned commit into ext/AtomVM. The branch has been rebased past that commit, so it is kept by a
# tag in elixir-hls/AtomVM, a fork, until the port is in AtomVM itself.
# Requires: git, cmake, ninja, gperf, Erlang/OTP (erlc), zlib.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
URL=https://github.com/elixir-hls/AtomVM.git
TAG=atomvm-tang25k-0.1.0
SHA=091c4fd8425675a932ebb8d5b462648b726dae1d
DIR="$ATOMVM_DIR"
if [ ! -d "$DIR/.git" ]; then
    git clone --no-checkout --branch "$TAG" "$URL" "$DIR"
fi
# the commit, by its SHA (a workspace cloned before from elsewhere fetches it from the fork)
git -C "$DIR" cat-file -e "$SHA^{commit}" 2>/dev/null || git -C "$DIR" fetch --quiet "$URL" "$SHA"
git -C "$DIR" checkout --quiet --force "$SHA"   # drops local edits; patches/ are re-applied below
for p in "$ROOT"/patches/atomvm/*.patch; do
    git -C "$DIR" apply --check "$p" 2>/dev/null && git -C "$DIR" apply "$p" && echo "applied $(basename "$p")"
done
echo "AtomVM at $(git -C "$DIR" rev-parse --short HEAD) in $DIR"
