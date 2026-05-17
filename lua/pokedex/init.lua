---@class pokedex.Highlight
---@field row integer 0-indexed row within the block
---@field col integer 0-indexed byte column where the highlight starts
---@field end_col integer 0-indexed byte column where the highlight ends (exclusive)
---@field fg? string hex color like "#fecc00" for foreground
---@field bg? string hex color for background
---@field hl? string named Neovim highlight group (alternative to fg/bg)

---@class pokedex.Block
---@field lines string[] one display row per entry, uniform display width
---@field highlights pokedex.Highlight[]

---@class pokedex.Sprite
---@field width integer
---@field height integer
---@field palette string[] hex colors (no leading `#`), 1-indexed via the pixel chars
---@field pixels string[] one row per entry; chars: `.`=transparent, `1`-`9`/`a`-`z`=palette index

---@class pokedex.RenderResult: pokedex.Block
---@field id string canonical "category/name" id of the rendered sprite

---@class pokedex.SetupOpts
---@field alpha? number blend factor 0..1 (default 1.0, no blend)
---@field bg? string target bg hex; auto-detected from `Normal` if absent, falls back to `#000000`
---@field outline? string override sprite outline (palette index 1). Hex (`"#fafafa"`) or hl group name (`"Title"`, resolved to fg)

---@class pokedex.PickOpts
---@field id? string canonical "category/name" id; if omitted, picks randomly within `category`
---@field category? string sprite category (default `"all"` = pick across all categories)
---@field outline? string per-call outline override (same accepted forms as setup). Wins over the setup value

---@class pokedex.TextOpts
---@field hl? string highlight group applied uniformly to every line

---@class pokedex.SnacksSectionOpts: pokedex.PickOpts
---Composition mode is active when `blocks` is present; otherwise the spec
---wraps a single sprite chosen by `id`/`category`. Any keys not listed below
---(e.g. `align`, `padding`, `pane`, `indent`) are forwarded onto the
---returned snacks section spec as-is.
---@field blocks? pokedex.Block[] composed left-to-right blocks
---@field gap? integer spaces between composed blocks (default 2)
---@field anchor? integer 1-indexed block to centre at screen-centre

local M = {}

local render = require("pokedex.render")

local config = {
  alpha = 1.0,
  bg = nil,
  outline = nil,
}

local function auto_detect_bg()
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "Normal" })
  if ok and hl and hl.bg then
    return string.format("#%06x", hl.bg)
  end
  return nil
end

-- Accept either a hex string ("#fafafa") or an hl group name ("Title").
-- Returns a `#rrggbb` string, or nil if unresolvable.
local function resolve_color(value)
  if value == nil then
    return nil
  end
  if type(value) == "string" and value:sub(1, 1) == "#" then
    return value
  end
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = value, link = false })
  if ok and hl and hl.fg then
    return string.format("#%06x", hl.fg)
  end
  return nil
end

local function effective_opts(override)
  override = override or {}
  -- Priority: explicit opts.bg > Normal hl bg > black fallback.
  return {
    alpha = config.alpha,
    bg = config.bg or auto_detect_bg() or "#000000",
    outline = resolve_color(override.outline or config.outline),
  }
end

local function list_sprite_ids(category)
  local pattern = category == "all" and "lua/pokedex/sprites/*/*.lua"
    or ("lua/pokedex/sprites/" .. category .. "/*.lua")
  local files = vim.api.nvim_get_runtime_file(pattern, true)
  local ids = {}
  for _, f in ipairs(files) do
    local id = f:match("lua/pokedex/sprites/([^/]+/[^/]+)%.lua$")
    if id then
      table.insert(ids, id)
    end
  end
  table.sort(ids)
  return ids
end

local function load_sprite(id)
  local path = vim.api.nvim_get_runtime_file("lua/pokedex/sprites/" .. id .. ".lua", false)[1]
  if not path then
    error(string.format("pokedex: sprite not found: %s", id))
  end
  return dofile(path)
end

local function resolve_id(opts)
  if opts.id then
    return opts.id
  end
  local category = opts.category or "all"
  local ids = list_sprite_ids(category)
  if #ids == 0 then
    error(string.format("pokedex: no sprites in category: %s", category))
  end
  return ids[math.random(#ids)]
end

--- Configure the plugin.
---@param opts? pokedex.SetupOpts
function M.setup(opts)
  opts = opts or {}
  if opts.alpha ~= nil then
    config.alpha = opts.alpha
  end
  if opts.bg ~= nil then
    config.bg = opts.bg
  end
  if opts.outline ~= nil then
    config.outline = opts.outline
  end
end

--- Render a sprite to lines + highlights.
---@param opts? pokedex.PickOpts
---@return pokedex.RenderResult
function M.render(opts)
  opts = opts or {}
  local id = resolve_id(opts)
  local sprite = load_sprite(id)
  local out = render.render(sprite, effective_opts(opts))
  out.id = id
  return out
end

--- Render a sprite as an ANSI escape string (for :terminal or `cat`).
---@param opts? pokedex.PickOpts
---@return string
function M.to_ansi(opts)
  opts = opts or {}
  local id = resolve_id(opts)
  return render.to_ansi(load_sprite(id), effective_opts(opts))
end

--- Build a text block from a string (or string array). Returns the same
--- `{ lines, highlights }` shape as `render()`, so it can sit alongside
--- sprite blocks inside `snacks_section({ blocks = { ... } })`.
---@param text string|string[]
---@param opts? pokedex.TextOpts
---@return pokedex.Block
function M.text(text, opts)
  opts = opts or {}
  local lines
  if type(text) == "string" then
    lines = vim.split(text, "\n", { plain = true })
  else
    lines = vim.deepcopy(text)
  end
  -- Trim whitespace-only lines from both ends (heredoc artefacts).
  while #lines > 0 and lines[1]:match("^%s*$") do
    table.remove(lines, 1)
  end
  while #lines > 0 and lines[#lines]:match("^%s*$") do
    table.remove(lines)
  end
  local highlights = {}
  if opts.hl then
    for i, line in ipairs(lines) do
      table.insert(highlights, { row = i - 1, col = 0, end_col = #line, hl = opts.hl })
    end
  end
  return { lines = lines, highlights = highlights }
end

local function max_display_width(lines)
  local w = 0
  for _, l in ipairs(lines) do
    w = math.max(w, vim.fn.strdisplaywidth(l))
  end
  return w
end

-- Internal: combine n blocks side-by-side, bottom-aligned, with `gap` spaces
-- between. If `anchor` is set (1-indexed), outer padding is added so that the
-- anchored block lands at the composed block's horizontal centre — when the
-- consumer (snacks) centres the composed block on screen, the anchored block
-- ends up centred on screen.
---@param blocks pokedex.Block[]
---@param opts? { gap?: integer, anchor?: integer }
---@return pokedex.Block
local function compose(blocks, opts)
  opts = opts or {}
  local gap = opts.gap or 2
  local anchor = opts.anchor

  if #blocks == 0 then
    return { lines = {}, highlights = {} }
  end

  local block_widths = {}
  local max_height = 0
  for i, b in ipairs(blocks) do
    block_widths[i] = max_display_width(b.lines or {})
    if #(b.lines or {}) > max_height then
      max_height = #b.lines
    end
  end

  -- Right-pad every line within each block to that block's max width.
  for i, b in ipairs(blocks) do
    for j, line in ipairs(b.lines) do
      b.lines[j] = line .. string.rep(" ", block_widths[i] - vim.fn.strdisplaywidth(line))
    end
  end

  local gap_str = string.rep(" ", gap)
  local out_lines = {}
  local out_hls = {}

  for r = 1, max_height do
    local parts = {}
    local block_starts = {}
    local byte_pos = 0
    for i, b in ipairs(blocks) do
      if i > 1 then
        table.insert(parts, gap_str)
        byte_pos = byte_pos + #gap_str
      end
      block_starts[i] = byte_pos
      local row_in_block = r - (max_height - #b.lines)
      local line
      if row_in_block >= 1 and row_in_block <= #b.lines then
        line = b.lines[row_in_block]
      else
        line = string.rep(" ", block_widths[i])
      end
      table.insert(parts, line)
      byte_pos = byte_pos + #line
    end
    out_lines[r] = table.concat(parts)

    for i, b in ipairs(blocks) do
      local row_in_block = r - (max_height - #b.lines)
      if row_in_block >= 1 and row_in_block <= #b.lines then
        for _, h in ipairs(b.highlights or {}) do
          if h.row == row_in_block - 1 then
            table.insert(out_hls, {
              row = r - 1,
              col = h.col + block_starts[i],
              end_col = h.end_col + block_starts[i],
              fg = h.fg,
              bg = h.bg,
              hl = h.hl,
            })
          end
        end
      end
    end
  end

  if anchor and anchor >= 1 and anchor <= #blocks then
    local left_w = 0
    for i = 1, anchor - 1 do
      left_w = left_w + block_widths[i] + gap
    end
    local right_w = 0
    for i = anchor + 1, #blocks do
      right_w = right_w + gap + block_widths[i]
    end
    if left_w < right_w then
      local pad = right_w - left_w
      local pad_str = string.rep(" ", pad)
      for i, l in ipairs(out_lines) do
        out_lines[i] = pad_str .. l
      end
      for _, h in ipairs(out_hls) do
        h.col = h.col + pad
        h.end_col = h.end_col + pad
      end
    elseif right_w < left_w then
      local pad = left_w - right_w
      local pad_str = string.rep(" ", pad)
      for i, l in ipairs(out_lines) do
        out_lines[i] = l .. pad_str
      end
    end
  end

  return { lines = out_lines, highlights = out_hls }
end

local hl_cache = {}
local function ensure_hl(fg, bg)
  local key = (fg or "_") .. "_" .. (bg or "_")
  if hl_cache[key] then
    return hl_cache[key]
  end
  local name = "PokedexSprite_" .. key:gsub("#", ""):gsub("_", "x")
  vim.api.nvim_set_hl(0, name, { fg = fg, bg = bg, default = false })
  hl_cache[key] = name
  return name
end

---@param data pokedex.Block
---@return table[] snacks-style chunks: { { text, hl? = group }, ... }
local function to_chunks(data)
  local lines = data.lines or {}
  local by_row = {}
  for _, h in ipairs(data.highlights or {}) do
    by_row[h.row] = by_row[h.row] or {}
    table.insert(by_row[h.row], h)
  end
  for _, hls in pairs(by_row) do
    table.sort(hls, function(a, b)
      return a.col < b.col
    end)
  end

  local chunks = {}
  for row_idx, line in ipairs(lines) do
    local hls = by_row[row_idx - 1] or {}
    local cursor = 0
    for _, h in ipairs(hls) do
      if h.col > cursor then
        table.insert(chunks, { line:sub(cursor + 1, h.col) })
      end
      table.insert(chunks, { line:sub(h.col + 1, h.end_col), hl = h.hl or ensure_hl(h.fg, h.bg) })
      cursor = h.end_col
    end
    if cursor < #line then
      table.insert(chunks, { line:sub(cursor + 1) })
    end
    if row_idx < #lines then
      table.insert(chunks, { "\n" })
    end
  end
  return chunks
end

--- Build a snacks dashboard section spec.
---
--- Single-sprite mode (default): pass `id` / `category` to pick a sprite.
---
--- Composition mode: pass `blocks`, an array of `{ lines, highlights }`
--- structures. Use `text()` and `render()` to construct them. Optional `gap`
--- (default 2) sets inter-block spacing and `anchor` (1-indexed) marks the
--- block to centre on screen.
---
--- Any keys other than the above are forwarded verbatim onto the snacks
--- section spec (e.g. `align`, `padding`, `pane`, `indent`).
---@param opts? pokedex.SnacksSectionOpts
---@return table snacks section spec
function M.snacks_section(opts)
  opts = opts or {}
  local data
  if opts.blocks ~= nil then
    data = compose(opts.blocks, { gap = opts.gap, anchor = opts.anchor })
  else
    data = M.render({ id = opts.id, category = opts.category, outline = opts.outline })
  end
  local spec = vim.tbl_extend("force", {}, opts)
  spec.id, spec.category, spec.outline = nil, nil, nil
  spec.blocks, spec.gap, spec.anchor = nil, nil, nil
  spec.text = to_chunks(data)
  return spec
end

return M
