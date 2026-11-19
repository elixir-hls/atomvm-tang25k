#!/usr/bin/env bash
# Fetch AtomVM with its Zephyr port (PR #2389, draft, release-0.7 based) at a pinned commit
# into ext/AtomVM. Requires: git, cmake, ninja, gperf, Erlang/OTP (erlc), zlib.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
URL=https://github.com/petermm/AtomVM.git
BRANCH=pr/958-rebased
SHA=091c4fd8425675a932ebb8d5b462648b726dae1d
DIR="$ATOMVM_DIR"
if [ ! -d "$DIR/.git" ]; then
    git clone --no-checkout --branch "$BRANCH" "$URL" "$DIR"
fi
# the commit itself, by its SHA: the branch may have moved on (been rebased) since it was pinned
git -C "$DIR" cat-file -e "$SHA^{commit}" 2>/dev/null || git -C "$DIR" fetch --quiet origin "$SHA"
git -C "$DIR" checkout --quiet --force "$SHA"   # drops local edits; patches/ are re-applied below
for p in "$ROOT"/patches/atomvm/*.patch; do
    git -C "$DIR" apply --check "$p" 2>/dev/null && git -C "$DIR" apply "$p" && echo "applied $(basename "$p")"
done
echo "AtomVM at $(git -C "$DIR" rev-parse --short HEAD) in $DIR"
