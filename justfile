# Run `just` with no argument to pick a recipe interactively.
[private]
default:
    @just --choose

# Convert every sprites/*/*.png to lua data files in the main branch (see scripts/build.sh for POKEDEX_MAIN_DIR override).
build:
    @nix develop --command bash scripts/build.sh

# Snap a single PNG to a GIMP palette (.gpl), overwriting the input.
snap png palette:
    @nix develop --command python3 scripts/snap_to_palette.py {{png}} {{palette}} {{png}}

# List every PNG that the build recipe would process.
list:
    @find sprites -type f -name '*.png' | sort

# Remove every generated .lua sprite data file from the main branch.
clean:
    #!/usr/bin/env bash
    main_dir="${POKEDEX_MAIN_DIR:-../pokedex.nvim}"
    target="$main_dir/lua/pokedex/sprites"
    if [ -d "$target" ]; then
        find "$target" -type f -name '*.lua' -delete
        echo "removed *.lua under $target"
    else
        echo "nothing to clean ($target does not exist)"
    fi
