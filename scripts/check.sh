#!/usr/bin/env bash
# LuaLS warning gate for leetcode.nvim.
#
# Runs lua-language-server --check across lua/ with the plugin's runtime deps on
# the library path, prints the diagnostics by code, and exits non-zero if any
# diagnostic appears that is not in the committed baseline (scripts/lls-baseline.txt).
#
# Comparison is by MESSAGE (code + file + text), NOT line number, so shifting a
# line cannot hide a newly introduced problem.
#
# Nothing machine-specific is committed: VIMRUNTIME and the lazy plugin dir are
# resolved at runtime. The throwaway luarc is written under .tmp/ (gitignored).
#
# Usage:
#   scripts/check.sh            # gate: exit 1 if diagnostics regress past baseline
#   scripts/check.sh --update   # rewrite the baseline from the current state
#
# Requires: lua-language-server, python3, and a Neovim (nightly preferred).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP="$ROOT/.tmp"
mkdir -p "$TMP"
BASELINE="$ROOT/scripts/lls-baseline.txt"
LUARC="$TMP/luarc-check.json"
OUT="$TMP/lls-check.json"

# --- resolve VIMRUNTIME: prefer bob nightly, else whatever nvim is on PATH ---
if [[ -z "${VIMRUNTIME:-}" ]]; then
  NIGHTLY="$HOME/Library/Application Support/bob/nvim-bin/nvim"
  NVIM="$([[ -x "$NIGHTLY" ]] && echo "$NIGHTLY" || command -v nvim || true)"
  if [[ -z "$NVIM" ]]; then
    echo "check.sh: no nvim found (need it to resolve VIMRUNTIME)" >&2
    exit 3
  fi
  VIMRUNTIME="$("$NVIM" --headless --cmd 'lua io.write(vim.env.VIMRUNTIME)' --cmd 'quit' 2>/dev/null)"
fi
export VIMRUNTIME

LAZY="${LC_DEPS:-$HOME/.local/share/nvim/lazy}"

# --- build a throwaway luarc = committed .luarc.json + resolved dep libraries ---
python3 -I - "$LUARC" "$VIMRUNTIME" "$LAZY" <<'PY'
import json, os, sys
out, vimruntime, lazy = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = json.load(open(".luarc.json"))
libs = [vimruntime + "/lua"]
for dep in ("plenary.nvim", "nui.nvim", "telescope.nvim", "image.nvim"):
    p = os.path.join(lazy, dep, "lua")
    if os.path.isdir(p):
        libs.append(p)
cfg["workspace.library"] = libs
json.dump(cfg, open(out, "w"), indent=2)
PY

rm -f "$OUT"
lua-language-server --check "$ROOT/lua" --checklevel=Warning \
  --check_format=json --check_out_path="$OUT" \
  --configpath="$LUARC" --logpath="$TMP/lls-log" >/dev/null 2>&1 || true

# --- compare by message against baseline; print summary; gate on regressions ---
python3 -I - "$OUT" "$BASELINE" "$ROOT" "${1:-}" <<'PY'
import json, os, sys, collections

out_path, baseline_path, root, mode = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

data = {}
if os.path.exists(out_path):
    try:
        data = json.load(open(out_path))
    except Exception:
        data = {}


def rel(uri):
    return uri.split("leetcode.nvim/")[-1]


# a stable fingerprint per diagnostic: file + code + first message line
current = set()
counts = collections.Counter()
for uri, arr in data.items():
    for d in arr:
        key = rel(uri) + "\t" + d["code"] + "\t" + d["message"].split("\n")[0].strip()
        current.add(key)
        counts[d["code"]] += 1

print("LuaLS diagnostics:", sum(counts.values()))
for code, n in counts.most_common():
    print(f"  {n:4}  {code}")

if mode == "--update":
    with open(baseline_path, "w") as f:
        for key in sorted(current):
            f.write(key + "\n")
    print(f"\nbaseline updated: {len(current)} accepted diagnostics -> {os.path.relpath(baseline_path, root)}")
    sys.exit(0)

baseline = set()
if os.path.exists(baseline_path):
    baseline = {ln.rstrip("\n") for ln in open(baseline_path) if ln.strip()}

new = current - baseline
fixed = baseline - current

if fixed:
    print(f"\n{len(fixed)} baseline diagnostic(s) no longer present (consider --update):")
    for key in sorted(fixed):
        f, code, msg = key.split("\t", 2)
        print(f"  - {f}  {code}: {msg[:60]}")

if new:
    print(f"\nREGRESSION: {len(new)} new diagnostic(s) not in baseline:")
    for key in sorted(new):
        f, code, msg = key.split("\t", 2)
        print(f"  + {f}  {code}: {msg[:60]}")
    sys.exit(1)

print("\nOK: no diagnostics outside the baseline.")
PY
