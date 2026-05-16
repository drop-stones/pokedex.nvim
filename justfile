# Run `just` with no argument to pick a recipe interactively.
[private]
default:
    @just --choose

# Path to the pokedex.nvim main worktree (POKEDEX_MAIN_DIR overrides).
main := env_var_or_default("POKEDEX_MAIN_DIR", "../pokedex.nvim")

# Convert every sprites/*/*.png to lua data files in the main branch.
build:
    @POKEDEX_MAIN_DIR={{main}} nix develop --command bash scripts/build.sh

# Snap a single PNG to a GIMP palette (.gpl), overwriting the input.
snap png palette:
    @nix develop --command python3 scripts/snap_to_palette.py {{png}} {{palette}} {{png}}

# List every PNG that the build recipe would process.
list:
    @find sprites -type f -name '*.png' | sort

# Format every Lua file in the main branch with stylua.
format:
    @nix develop --command stylua {{main}}/lua {{main}}/tests

# Verify Lua formatting without modifying files.
format-check:
    @nix develop --command stylua --check {{main}}/lua {{main}}/tests

# Run the plugin smoke tests in headless nvim.
test:
    @nvim --headless --noplugin -u NONE \
        -c "set rtp+={{main}}" \
        -c "luafile {{main}}/tests/smoke.lua" \
        -c "qa"

# Remove every generated .lua sprite data file from the main branch.
clean:
    #!/usr/bin/env bash
    target="{{main}}/lua/pokedex/sprites"
    if [ -d "$target" ]; then
        find "$target" -type f -name '*.lua' -delete
        echo "removed *.lua under $target"
    else
        echo "nothing to clean ($target does not exist)"
    fi
