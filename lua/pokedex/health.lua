local M = {}

local function inventory()
  local files = vim.api.nvim_get_runtime_file("lua/pokedex/sprites/*/*.lua", true)
  local by_cat = {}
  for _, f in ipairs(files) do
    local cat = f:match("lua/pokedex/sprites/([^/]+)/")
    if cat then
      by_cat[cat] = (by_cat[cat] or 0) + 1
    end
  end
  return files, by_cat
end

function M.check()
  vim.health.start("pokedex.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10+")
  else
    vim.health.warn(
      "Neovim 0.10+ recommended (older versions are untested)",
      "Upgrade Neovim if rendering misbehaves."
    )
  end

  if vim.o.termguicolors then
    vim.health.ok("`termguicolors` is enabled")
  else
    vim.health.error(
      "`termguicolors` is disabled; per-cell RGB highlights will not render",
      "Set `vim.opt.termguicolors = true` in your config."
    )
  end

  local hl_ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "Normal" })
  if hl_ok and hl and hl.bg then
    vim.health.ok(string.format("`Normal` bg auto-detected: #%06x (used as alpha-blend target)", hl.bg))
  else
    vim.health.warn(
      "`Normal` highlight has no bg; alpha blend falls back to `#000000`",
      "Set `require('pokedex').setup({ bg = '#...' })` to override."
    )
  end

  local files, by_cat = inventory()
  if #files == 0 then
    vim.health.error(
      "No sprites found under `lua/pokedex/sprites/*/*.lua`",
      "The plugin install may be incomplete; reinstall via your plugin manager."
    )
    return
  end
  local parts = {}
  for cat, n in pairs(by_cat) do
    table.insert(parts, string.format("%s: %d", cat, n))
  end
  table.sort(parts)
  vim.health.ok(string.format("Sprites loaded — %d total (%s)", #files, table.concat(parts, ", ")))

  local sample_id = files[1]:match("lua/pokedex/sprites/([^/]+/[^/]+)%.lua")
  if sample_id then
    local rok, rerr = pcall(function()
      return require("pokedex").render({ id = sample_id })
    end)
    if rok then
      vim.health.ok(string.format("Sample render OK (`%s`)", sample_id))
    else
      vim.health.error(
        string.format("Sample render failed for `%s`: %s", sample_id, tostring(rerr)),
        "Run `:lua print(vim.inspect(require('pokedex').render()))` for details."
      )
    end
  end
end

return M
