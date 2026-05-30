-- Smoke tests: exercise the public API end-to-end via headless nvim.
-- Run with `just test` from the assets worktree, or directly:
--   nvim --headless --noplugin -u NONE \
--     -c "set rtp+=." -c "luafile tests/smoke.lua" -c "qa"

local p = require("pokedex")

local failures = {}
local total = 0

local function check(name, fn)
  total = total + 1
  local ok, err = pcall(fn)
  if ok then
    io.write(".")
  else
    io.write("F")
    table.insert(failures, { name = name, err = err })
  end
end

-- ---------- render / to_ansi ----------

check("render() returns block with id, lines, highlights", function()
  p.setup({ alpha = 1.0 })
  local r = p.render()
  assert(type(r.id) == "string", "id should be string")
  assert(type(r.lines) == "table" and #r.lines > 0, "lines should be non-empty")
  assert(type(r.highlights) == "table", "highlights should be table")
end)

check("render({id=...}) picks the requested sprite", function()
  local r = p.render({ id = "pokemon/025" })
  assert(r.id == "pokemon/025", "wanted pokemon/025, got " .. tostring(r.id))
end)

check("render({category=...}) stays within the category", function()
  for _ = 1, 25 do
    local r = p.render({ category = "pokeball" })
    assert(r.id:sub(1, 9) == "pokeball/", "expected pokeball/*, got " .. r.id)
  end
end)

check("render() (default category=all) eventually mixes categories", function()
  local seen = {}
  for _ = 1, 200 do
    seen[p.render().id:match("^[^/]+/")] = true
  end
  assert(seen["pokemon/"] and seen["pokeball/"], "expected both categories to appear")
end)

check("to_ansi() embeds ANSI SGR sequences", function()
  local s = p.to_ansi({ id = "pokemon/025" })
  assert(type(s) == "string")
  assert(s:find("\27%[38;2;"), "expected truecolor fg escape")
end)

check("render alpha=1.0 emits pure palette colors", function()
  p.setup({ alpha = 1.0, bg = "#000000" })
  local r = p.render({ id = "pokeball/poke" })
  local saw_red = false
  for _, h in ipairs(r.highlights) do
    if h.fg == "#e83828" or h.bg == "#e83828" then
      saw_red = true
      break
    end
  end
  assert(saw_red, "expected canonical red #e83828 to appear without blend")
end)

check("render alpha=0.5 against white blends colors", function()
  p.setup({ alpha = 0.5, bg = "#ffffff" })
  local r = p.render({ id = "pokeball/poke" })
  for _, h in ipairs(r.highlights) do
    assert(h.fg ~= "#000000" and h.bg ~= "#000000", "pure black should be blended away")
  end
end)

-- ---------- outline ----------

local function has_color(highlights, hex)
  for _, h in ipairs(highlights) do
    if h.fg == hex or h.bg == hex then
      return true
    end
  end
  return false
end

check("setup outline as hex replaces black outline", function()
  p.setup({ alpha = 1.0, bg = "#000000", outline = "#ff00ff" })
  local r = p.render({ id = "pokeball/poke" })
  assert(has_color(r.highlights, "#ff00ff"), "expected outline color to appear")
  assert(not has_color(r.highlights, "#000000"), "expected original black outline to be gone")
  p.setup({ outline = nil })
end)

check("setup outline as hl group resolves to fg", function()
  vim.api.nvim_set_hl(0, "PokedexTestTitle", { fg = "#abcdef" })
  p.setup({ alpha = 1.0, bg = "#000000", outline = "PokedexTestTitle" })
  local r = p.render({ id = "pokeball/poke" })
  assert(has_color(r.highlights, "#abcdef"), "expected hl group fg to be applied as outline")
  p.setup({ outline = nil })
end)

check("render-time outline wins over setup outline", function()
  p.setup({ alpha = 1.0, bg = "#000000", outline = "#ff0000" })
  local r = p.render({ id = "pokeball/poke", outline = "#00ff00" })
  assert(has_color(r.highlights, "#00ff00"), "expected per-call outline to win")
  assert(not has_color(r.highlights, "#ff0000"), "setup outline should be overridden")
  p.setup({ outline = nil })
end)

check("unresolvable outline hl group falls back to sprite default", function()
  p.setup({ alpha = 1.0, bg = "#000000", outline = "NonExistentHlGroup_xyz" })
  local r = p.render({ id = "pokeball/poke" })
  assert(has_color(r.highlights, "#000000"), "expected sprite's original black outline as fallback")
  p.setup({ outline = nil })
end)

-- ---------- text() ----------

check("text(string) returns a block with one line per newline", function()
  local b = p.text("foo\nbar\nbaz")
  assert(#b.lines == 3, "want 3 lines, got " .. #b.lines)
  assert(#b.highlights == 0, "no hl when opts.hl missing")
end)

check("text(...) applies hl uniformly per line", function()
  local b = p.text("hello\nworld", { hl = "Title" })
  assert(#b.highlights == 2)
  for _, h in ipairs(b.highlights) do
    assert(h.hl == "Title")
  end
end)

check("text(...) trims whitespace-only border lines", function()
  local b = p.text("\n  \nfoo\nbar\n\n")
  assert(#b.lines == 2)
  assert(b.lines[1] == "foo")
  assert(b.lines[2] == "bar")
end)

check("text(array) accepts a string array directly", function()
  local b = p.text({ "one", "two" }, { hl = "Comment" })
  assert(#b.lines == 2)
  assert(b.highlights[1].hl == "Comment")
end)

-- ---------- snacks_section ----------

check("snacks_section() single-sprite mode returns text chunks", function()
  local s = p.snacks_section({ id = "pokemon/025" })
  assert(type(s.text) == "table" and #s.text > 0)
end)

check("snacks_section() strips internal keys from spec", function()
  local s = p.snacks_section({ id = "pokemon/025", category = "all", padding = 1 })
  assert(s.id == nil and s.category == nil, "internal keys must not leak")
end)

check("snacks_section() forwards arbitrary snacks keys", function()
  local s = p.snacks_section({ id = "pokemon/025", align = "center", padding = 1, pane = 2 })
  assert(s.align == "center" and s.padding == 1 and s.pane == 2)
end)

check("snacks_section({blocks=...}) composes correctly", function()
  local s = p.snacks_section({
    blocks = { p.text("LOGO", { hl = "Title" }), p.render({ id = "pokemon/025" }) },
    anchor = 1,
  })
  assert(type(s.text) == "table" and #s.text > 0)
end)

-- ---------- sprite inventory ----------

check("every installed sprite can be loaded without error", function()
  local files = vim.api.nvim_get_runtime_file("lua/pokedex/sprites/*/*.lua", true)
  assert(#files > 0, "no sprites found")
  for _, path in ipairs(files) do
    local id = vim.fs.normalize(path):match("lua/pokedex/sprites/([^/]+/[^/]+)%.lua$")
    if id then
      local r = p.render({ id = id })
      assert(r.id == id)
    end
  end
end)

-- ---------- summary ----------

io.write("\n\n")
print(string.format("%d / %d passed", total - #failures, total))
for _, f in ipairs(failures) do
  print("\nFAIL " .. f.name)
  print("  " .. tostring(f.err))
end
if #failures > 0 then
  os.exit(1)
end
