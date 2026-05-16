# pokedex.nvim

Random Pokémon pixel art for your Neovim dashboard.

![demo](https://raw.githubusercontent.com/drop-stones/pokedex.nvim/assets/screenshots/pokedex.png)

## ✨ Features

- 🎨 12 hand-drawn sprites (3 Gen 1 + 3 Gen 2 starters + Pikachu, 5 Poké Ball variants)
- ⚡ Pure half-block (`▀` `▄`) rendering — no external image protocol required
- 🌗 Optional alpha blend against your colorscheme
- 🧩 First-class [snacks.nvim](https://github.com/folke/snacks.nvim) dashboard adapter
- 🌱 Bring your own sprites: piskel → PNG → `just build`

## 📦 Requirements

- Neovim >= **0.10**
- `vim.opt.termguicolors = true`
- For dashboard integration: [snacks.nvim](https://github.com/folke/snacks.nvim)

## 🚀 Installation

```lua
-- lazy.nvim
{
  "drop-stones/pokedex.nvim",
  opts = { alpha = 0.85 },  -- optional softness (default 1.0 = pure color)
}
```

> [!TIP]
> Run `:checkhealth pokedex` to verify your setup.

## ⚙️ Configuration

| Key     | Type      | Default | Description                                                                   |
| ------- | --------- | ------- | ----------------------------------------------------------------------------- |
| `alpha` | `number`  | `1.0`   | Blend factor against `bg` (`0` ≈ invisible, `1` = pure palette color)         |
| `bg`    | `string?` | auto    | Hex bg used for blending. Defaults to `Normal` hl bg; falls back to `#000000` |

## 🐾 Usage

Most common setup — snacks's `header` centred, a random sprite hanging to its right:

```lua
{
  "folke/snacks.nvim",
  dependencies = { "drop-stones/pokedex.nvim" },
  opts = {
    dashboard = {
      sections = {
        function(self)
          local p = require("pokedex")
          return p.snacks_section({
            blocks = {
              p.text(self.opts.preset.header, { hl = "Title" }),
              p.render(),
            },
            anchor = 1,    -- centre the logo at screen-centre; sprite hangs right
            padding = 1,
          })
        end,
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },
}
```

Other shapes:

```lua
local p = require("pokedex")

p.snacks_section()                                  -- random sprite, nothing else
p.snacks_section({ id = "pokemon/025" })            -- always Pikachu
p.snacks_section({ category = "pokeball" })         -- random Poké Ball

-- multiple sprites side-by-side, middle one centred on screen
p.snacks_section({
  blocks = { p.render({ id = "pokemon/001" }), p.render(), p.render({ id = "pokemon/007" }) },
  anchor = 2,
})
```

## 🔧 API

| Function               | Returns                       | Description                                                              |
| ---------------------- | ----------------------------- | ------------------------------------------------------------------------ |
| `setup(opts)`          | —                             | Configure `alpha` / `bg`                                                 |
| `render(opts)`         | `{ lines, highlights, id }`   | Structured pixel data (lines + per-cell fg/bg) for buffer rendering      |
| `to_ansi(opts)`        | `string`                      | Same sprite as ANSI escape sequences for terminals (`cat`, `:terminal`)  |
| `text(text, opts?)`    | `{ lines, highlights }`       | Build a text block usable inside `snacks_section({ blocks = … })`        |
| `snacks_section(opts)` | snacks `dashboard.Item`       | Wrap a sprite or `blocks` composition; extra keys forward onto the spec  |

`opts.id` is `"category/name"` (e.g. `"pokemon/025"`); `opts.category` scopes the random pick (default `"all"`). On `snacks_section`, the composition mode (`blocks` array) supports `gap` and `anchor` (1-indexed block to centre on screen).

## 🎨 Available sprites

| Category   | IDs                                                                                                                |
| ---------- | ------------------------------------------------------------------------------------------------------------------ |
| `pokemon`  | `001` Bulbasaur, `004` Charmander, `007` Squirtle, `025` Pikachu, `152` Chikorita, `155` Cyndaquil, `158` Totodile |
| `pokeball` | `poke`, `great`, `ultra`, `master`, `premier`                                            |

New sprites are authored on the [`assets`](https://github.com/drop-stones/pokedex.nvim/tree/assets) branch and compiled into Lua via `just build`.

## 🩺 Troubleshooting

Run `:checkhealth pokedex`.

## 📜 License

MIT — see [LICENSE](LICENSE).

> [!NOTE]
> Pokémon characters and names are trademarks of Nintendo / Game Freak / The Pokémon Company. Sprites are hand-drawn at small custom sizes (not extracted from any Nintendo asset) but still depict copyrighted characters. This is an unaffiliated, non-commercial project; the MIT grant covers source code only.
