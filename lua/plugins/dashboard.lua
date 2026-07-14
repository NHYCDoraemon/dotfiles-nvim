-- Giant gradient wordmark dashboard.
--
--   NHYC   → huge ANSI-Shadow block letters, per-letter gradient
--   Doraemon → small gradient subtitle beneath
--
-- The gradient is NOT hardcoded: NhycGrad1..4 are recomputed from the ACTIVE
-- colorscheme on every ColorScheme event (see gradient() below), so it warms to
-- rose-pine by day and cools to catppuccin-frappe by night — matching the
-- auto day/night theme in lua/config/auto-theme.lua.

-- ── theme-following gradient highlight groups ────────────────────────────────
local function gradient()
  local function fg(name)
    local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok and h and h.fg then return h.fg end
    return nil
  end
  -- Two accent anchors sampled from the active theme; every colorscheme defines
  -- these, so the gradient adapts automatically.
  local c1 = fg("Function") or fg("Special") or 0x9ccfd8
  local c2 = fg("Keyword") or fg("Statement") or fg("Constant") or 0xc4a7e7

  local function lerp(a, b, t)
    local ar, ag, ab = math.floor(a / 65536) % 256, math.floor(a / 256) % 256, a % 256
    local br, bg, bb = math.floor(b / 65536) % 256, math.floor(b / 256) % 256, b % 256
    return string.format("#%02x%02x%02x",
      math.floor(ar + (br - ar) * t + 0.5),
      math.floor(ag + (bg - ag) * t + 0.5),
      math.floor(ab + (bb - ab) * t + 0.5))
  end

  for i = 1, 4 do
    vim.api.nvim_set_hl(0, "NhycGrad" .. i, { fg = lerp(c1, c2, (i - 1) / 3), bold = true })
  end
  vim.api.nvim_set_hl(0, "DoraemonSub", { fg = fg("Comment") or fg("NonText") or 0x6e6a86, italic = true })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("nhyc_dashboard_gradient", { clear = true }),
  callback = vim.schedule_wrap(gradient),
})
vim.schedule(gradient) -- apply once now, in case the colorscheme already loaded

-- ── ANSI-Shadow block letters (6 rows each) ──────────────────────────────────
local N = { "███╗   ██╗", "████╗  ██║", "██╔██╗ ██║", "██║╚██╗██║", "██║ ╚████║", "╚═╝  ╚═══╝" }
local H = { "██╗  ██╗", "██║  ██║", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝" }
local Y = { "██╗   ██╗", "╚██╗ ██╔╝", " ╚████╔╝ ", "  ╚██╔╝  ", "   ██║   ", "   ╚═╝   " }
local C = { " ██████╗", "██╔════╝", "██║     ", "██║     ", "╚██████╗", " ╚═════╝" }

-- ── one source of truth for the action keys (drives both display AND bindings)─
local dev_roots = { "~/ideaProjects", "~/GolandProjects", "~/projects" }
local actions = {
  { key = "f", desc = "Find File",       run = function() Snacks.dashboard.pick("files") end },
  { key = "n", desc = "New File",        run = function() vim.cmd("ene | startinsert") end },
  { key = "g", desc = "Find Text",       run = function() Snacks.dashboard.pick("live_grep") end },
  { key = "r", desc = "Recent Files",    run = function() Snacks.dashboard.pick("oldfiles") end },
  { key = "p", desc = "Projects",        run = function() Snacks.picker.projects({ dev = dev_roots }) end },
  { key = "c", desc = "Configuration",   run = function() Snacks.dashboard.pick("files", { cwd = vim.fn.stdpath("config") }) end },
  { key = "s", desc = "Restore Session", run = function() local ok, p = pcall(require, "persistence"); if ok then p.load() end end },
  { key = "z", desc = "Zen Mode",        run = function() vim.cmd("ZenMode") end },
  { key = "l", desc = "Lazy",            run = function() vim.cmd("Lazy") end },
  { key = "q", desc = "Quit",            run = function() vim.cmd("qa") end },
}

-- Bind the letters as buffer-local maps on the dashboard (we render a custom
-- 2-column layout instead of the built-in keys section, so we wire keys ourselves).
--
-- We hook `User SnacksDashboardOpened`, NOT `FileType snacks_dashboard`: snacks
-- sets the dashboard buffer's filetype under `eventignore=all` (dashboard.lua
-- D:init), so the FileType event never fires. Without our maps, unmapped letters
-- fall through to normal mode — e.g. `p` becomes paste, and with
-- clipboard=unnamedplus an empty system clipboard raises "Register + is empty".
vim.api.nvim_create_autocmd("User", {
  pattern = "SnacksDashboardOpened",
  group = vim.api.nvim_create_augroup("nhyc_dashboard_keys", { clear = true }),
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype ~= "snacks_dashboard" then
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].filetype == "snacks_dashboard" then
          buf = b
          break
        end
      end
    end
    for _, a in ipairs(actions) do
      vim.keymap.set("n", a.key, a.run, { buffer = buf, nowait = true, silent = true, desc = a.desc })
    end
  end,
})

return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      local greet_h = tonumber(os.date("%H"))
      local greet = greet_h < 5 and "Late night" or greet_h < 11 and "Good morning"
        or greet_h < 14 and "Good afternoon" or greet_h < 18 and "Good afternoon" or "Good evening"
      local am = require("config.auto-theme")
      local mode = am.is_dark() and ("☾ " .. am.night) or ("☀ " .. am.day)
      local date = os.date("%a %d %b")

      -- Build the 6 header lines: each row = N|H|Y|C, one gradient hl per letter.
      local header = {}
      for i = 1, 6 do
        header[#header + 1] = {
          align = "center",
          text = {
            { N[i], hl = "NhycGrad1" }, { " " },
            { H[i], hl = "NhycGrad2" }, { " " },
            { Y[i], hl = "NhycGrad3" }, { " " },
            { C[i], hl = "NhycGrad4" },
          },
        }
      end

      -- 2-column keys: left = actions[1..5], right = actions[6..10].
      local keyrows = {}
      for i = 1, 5 do
        local l, r = actions[i], actions[i + 5]
        keyrows[#keyrows + 1] = {
          align = "center",
          text = {
            { "[ ", hl = "SnacksDashboardDir" }, { l.key, hl = "SnacksDashboardSpecial" }, { " ] ", hl = "SnacksDashboardDir" },
            { string.format("%-15s", l.desc), hl = "SnacksDashboardDesc" },
            { "  " },
            { "[ ", hl = "SnacksDashboardDir" }, { r.key, hl = "SnacksDashboardSpecial" }, { " ] ", hl = "SnacksDashboardDir" },
            -- pad the right desc too so every row has identical total width →
            -- snacks' center offset (floor((width-len)/2)) is constant → the LEFT
            -- column's brackets line up instead of drifting right row by row.
            { string.format("%-15s", r.desc), hl = "SnacksDashboardDesc" },
          },
        }
      end

      local sections = {}
      vim.list_extend(sections, header)
      -- Doraemon subtitle + greeting.
      sections[#sections + 1] = { text = { { "˗ˏˋ  D o r a e m o n  ´ˎ˗", hl = "DoraemonSub" } }, align = "center", padding = 1 }
      sections[#sections + 1] = {
        text = {
          { "❯ ", hl = "SnacksDashboardDir" },
          { greet .. ", NHYC", hl = "SnacksDashboardTitle" },
          { "  ·  " .. date .. "  ·  " .. mode, hl = "SnacksDashboardDir" },
        },
        align = "center",
        padding = 2,
      }
      vim.list_extend(sections, keyrows)
      -- Recent files.
      sections[#sections + 1] = { padding = 2 }
      sections[#sections + 1] = { text = { { "Recent", hl = "SnacksDashboardTitle" } }, align = "center", padding = 1 }
      sections[#sections + 1] = { section = "recent_files", limit = 4, padding = 1, indent = 0, align = "center" }
      -- Footer: plugin count + load time.
      sections[#sections + 1] = { padding = 2 }
      sections[#sections + 1] = { section = "startup", align = "center" }

      opts.dashboard = opts.dashboard or {}
      opts.dashboard.enabled = true
      opts.dashboard.width = 72
      opts.dashboard.sections = sections
      opts.dashboard.preset = { keys = {} } -- we bind keys ourselves (see FileType autocmd)
      return opts
    end,
  },
}
