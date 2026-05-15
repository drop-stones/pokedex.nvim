# pokedex.nvim

A Neovim plugin that displays random Pokémon pixel art on the dashboard.

## Goal

Provide a small, self-contained Lua plugin that exposes a section for
[snacks.nvim](https://github.com/folke/snacks.nvim) dashboard. The section
renders a randomly-picked Pokémon sprite next to (or as part of) the
dashboard layout.

## Scope (v1)

- **Pokémon only.** Other Nintendo IP (Mario, Zelda, ...) is intentionally
  out of scope — keeps the sprite style coherent and the project shippable.
- **~10 hand-curated sprites to start.** Grow over time; the plugin name
  ("pokedex") is aspirational, not a completeness claim.
- **Dashboard-only use case.** No CLI form, no statusline integration. If a
  terminal use case appears later, factor out then.

## Display constraints

- **Height: ~8 terminal rows.** Aligned with the height of the default
  snacks.nvim Neovim ASCII header, so sprites sit beside it cleanly.
- **Rendering: half-block (`▀`)** — each cell renders two vertical pixels,
  so an 8-row sprite = source artwork up to ~16 pixels tall.
- **Width: unconstrained, but keep visually balanced** with the rest of the
  dashboard (rough target: 16–24 cells wide).

## Implementation approach

- **Pure Lua plugin.** No external CLI dependency, no compilation, works on
  any OS Neovim runs on.
- **Sprite data is embedded.** Each sprite is a pre-rendered ANSI escape
  sequence (or a Lua table that the runtime turns into one). Format TBD —
  start with whichever is simplest to author and inspect.
- **Layout (tentative):**
  ```
  lua/pokedex/
    init.lua          -- setup + snacks section provider
    sprites/
      001.txt         -- pre-rendered ANSI per Pokémon
      ...
  ```
- **Public API (tentative):** a function that returns a snacks dashboard
  section spec, so users can drop it into their `sections` table.

## IP and licensing

Pokémon characters and names are owned by Nintendo / Game Freak / The
Pokémon Company. The sprites shipped here are **hand-drawn at a custom
small size** — not extracted from any Nintendo asset — but they still
depict copyrighted/trademarked characters, so they are legally derivative
works.

Practical risk profile: comparable to long-standing tools like
[krabby](https://github.com/yannjor/krabby) and
[pokemon-colorscripts](https://gitlab.com/phoneybadger/pokemon-colorscripts)
— no enforcement history at this scale, but not zero.

- **License: MIT** for the code. Standard for the Pokémon-CLI ecosystem.
- The MIT grant covers the code only; we cannot grant rights we do not own
  over the depicted characters. This is implicitly understood, the same way
  krabby/pokemon-colorscripts handle it.
- **README must carry a disclaimer** noting the trademark ownership and the
  non-commercial / unaffiliated nature of the project.

## Decisions log (for future reference)

- **Name `pokedex.nvim`** chosen over more generic alternatives
  (`dashpix`, `pocketpix`, `dexlet`, ...). "Pokédex" is technically a
  Nintendo trademark, but widespread unenforced OSS usage and immediate
  name-function fit outweighed the trademark concern.
- **CLI form rejected.** No use case beyond the dashboard; a plugin is
  simpler to install (no cargo/go), and integrates directly with snacks.
- **Sprite embedding chosen over runtime fetch (PokéAPI etc.).** Avoids
  network dependency at dashboard startup and keeps the plugin offline.
- **Half-block rendering chosen** over single-cell or ASCII. Half-block
  gives 2x vertical resolution per cell, which is the minimum needed for
  recognizable Pokémon at this size.

## Coding conventions

Inherited from the author's global rules — language: English for all code,
comments, commit messages, and documentation. Keep code simple. Write tests
when feasible.

Commits follow **Conventional Commits with a scope**, split into the
smallest semantically meaningful units, e.g.:

- `feat(sprites): add gen-1 starters`
- `feat(snacks): expose dashboard section provider`
- `fix(render): handle terminals without true-color support`

Never commit without explicit author approval.

## Workflow

1. **Discuss first.** Agree on a spec before implementing.
2. **Implement.** Adjustments during implementation are fine.
3. **Wait for verification.** The author tests and confirms.
4. **Commit only after approval.**
