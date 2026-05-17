local M = {}

local UPPER = "\u{2580}"
local LOWER = "\u{2584}"

local function hex_to_rgb(hex)
  hex = hex:gsub("^#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x", r, g, b)
end

local function blend_one(fg_hex, bg_rgb, alpha)
  local fr, fg, fb = hex_to_rgb(fg_hex)
  local br, bgg, bb = bg_rgb[1], bg_rgb[2], bg_rgb[3]
  return rgb_to_hex(
    math.floor(fr * alpha + br * (1 - alpha) + 0.5),
    math.floor(fg * alpha + bgg * (1 - alpha) + 0.5),
    math.floor(fb * alpha + bb * (1 - alpha) + 0.5)
  )
end

local function decode_idx(ch)
  if ch == "." or ch == "" then
    return 0
  end
  return tonumber(ch, 36)
end

local function blended_palette(sprite, alpha, bg_hex, outline)
  local out = {}
  if alpha >= 1.0 or not bg_hex then
    for i, c in ipairs(sprite.palette) do
      out[i] = "#" .. c
    end
    if outline then
      out[1] = outline
    end
    return out
  end
  local br, bg, bb = hex_to_rgb(bg_hex)
  for i, c in ipairs(sprite.palette) do
    out[i] = blend_one(c, { br, bg, bb }, alpha)
  end
  if outline then
    out[1] = blend_one(outline, { br, bg, bb }, alpha)
  end
  return out
end

--- Render a sprite to a structured form usable by Neovim buffers.
---@param sprite pokedex.Sprite
---@param opts? { alpha?: number, bg?: string, outline?: string }
---@return pokedex.Block
function M.render(sprite, opts)
  opts = opts or {}
  local alpha = opts.alpha or 1.0
  local bg = opts.bg
  local outline = opts.outline
  assert(sprite.height % 2 == 0, "sprite height must be even")

  local palette = blended_palette(sprite, alpha, bg, outline)
  local lines = {}
  local highlights = {}

  for row = 0, (sprite.height / 2) - 1 do
    local top_row = sprite.pixels[row * 2 + 1]
    local bot_row = sprite.pixels[row * 2 + 2]
    local parts = {}
    local byte_col = 0
    for col = 1, sprite.width do
      local t = decode_idx(top_row:sub(col, col))
      local b = decode_idx(bot_row:sub(col, col))
      local char, fg, bg_col
      if t == 0 and b == 0 then
        char = " "
      elseif b == 0 then
        char, fg = UPPER, palette[t]
      elseif t == 0 then
        char, fg = LOWER, palette[b]
      else
        char, fg, bg_col = UPPER, palette[t], palette[b]
      end
      local n = #char
      if fg then
        table.insert(highlights, {
          row = row,
          col = byte_col,
          end_col = byte_col + n,
          fg = fg,
          bg = bg_col,
        })
      end
      parts[#parts + 1] = char
      byte_col = byte_col + n
    end
    lines[#lines + 1] = table.concat(parts)
  end

  return { lines = lines, highlights = highlights }
end

--- Render a sprite as a single ANSI escape sequence string (for terminal use).
---@param sprite pokedex.Sprite
---@param opts? { alpha?: number, bg?: string, outline?: string }
---@return string
function M.to_ansi(sprite, opts)
  local rendered = M.render(sprite, opts)
  local out = {}
  local hl_by_row = {}
  for _, hl in ipairs(rendered.highlights) do
    hl_by_row[hl.row] = hl_by_row[hl.row] or {}
    table.insert(hl_by_row[hl.row], hl)
  end

  for row, line in ipairs(rendered.lines) do
    local row_hls = hl_by_row[row - 1] or {}
    table.sort(row_hls, function(a, b)
      return a.col < b.col
    end)
    local cursor = 0
    local pieces = {}
    for _, hl in ipairs(row_hls) do
      if hl.col > cursor then
        table.insert(pieces, line:sub(cursor + 1, hl.col))
      end
      local fr, fg, fb = hex_to_rgb(hl.fg)
      local seq = string.format("\27[38;2;%d;%d;%dm", fr, fg, fb)
      if hl.bg then
        local br, bgg, bb = hex_to_rgb(hl.bg)
        seq = seq .. string.format("\27[48;2;%d;%d;%dm", br, bgg, bb)
      end
      table.insert(pieces, seq .. line:sub(hl.col + 1, hl.end_col) .. "\27[0m")
      cursor = hl.end_col
    end
    if cursor < #line then
      table.insert(pieces, line:sub(cursor + 1))
    end
    table.insert(out, table.concat(pieces))
  end
  return table.concat(out, "\n")
end

return M
