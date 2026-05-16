#!/usr/bin/env bash
# Convert every sprites/<category>/<name>.png in this repo into its matching
# lua/pokedex/sprites/<category>/<name>.lua in the main branch worktree.
# Override the target with POKEDEX_MAIN_DIR (default: ../pokedex.nvim).
set -euo pipefail

main_dir="${POKEDEX_MAIN_DIR:-../pokedex.nvim}"
out_root="$main_dir/lua/pokedex/sprites"
echo "→ output: $out_root"

count=0
for png in sprites/*/*.png; do
    [ -e "$png" ] || continue
    rel="${png#sprites/}"
    out="$out_root/${rel%.png}.lua"
    mkdir -p "$(dirname "$out")"
    python3 scripts/png_to_lua.py "$png" "$out" >/dev/null 2>&1
    echo "  $rel"
    count=$((count + 1))
done
echo "built $count sprites"
