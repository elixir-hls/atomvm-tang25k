#!/usr/bin/env bash
# Print resource usage and Fmax of a LiteX/Gowin build directory.
set -euo pipefail
dir="${1:?usage: $0 <build dir>}"
grep -A30 "Resource Usage Summary" "$dir/gateware/impl/pnr/project.rpt.txt" \
    | grep -E "^\s+(Logic|Register|CLS|BSRAM|DSP|I/O Port)\s"
python3 - "$dir/gateware/impl/pnr/project_tr_content.html" <<'PY'
import html, re, sys
t = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", open(sys.argv[1], errors="ignore").read())))
m = re.search(r"Max Frequency Summary:(.*?)Total Negative Slack", t)
print("Fmax:", m.group(1).strip() if m else "?")
PY
