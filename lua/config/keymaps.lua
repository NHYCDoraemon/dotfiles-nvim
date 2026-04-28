-- Keymaps are automatically loaded on the VeryLazy event
-- IDEA macOS keymap layer. Requires terminal that forwards Cmd as <D-…> (Ghostty/Wezterm).

local map = vim.keymap.set
local del = function(mode, lhs) pcall(vim.keymap.del, mode, lhs) end

-- ============================================================
-- (1) EDITING
-- ============================================================
map({ "n", "v" }, "<D-c>", '"+y', { desc = "Copy" })
map({ "n", "v" }, "<D-x>", '"+d', { desc = "Cut" })
map("i",          "<D-v>", "<C-r>+", { desc = "Paste" })
map({ "n", "v" }, "<D-v>", '"+p', { desc = "Paste" })
map("n",          "<D-a>", "ggVG",  { desc = "Select all" })
map("n",          "<D-z>", "u",     { desc = "Undo" })
map("n",          "<D-S-z>", "<C-r>", { desc = "Redo" })
map("n",          "<D-d>", ":t.<CR>", { desc = "Duplicate line" })
map("v",          "<D-d>", "y'>p", { desc = "Duplicate selection" })
map("n",          "<D-BS>", "dd", { desc = "Delete line" })

-- Save:
--   <C-s>  works everywhere (any terminal, no Cmd forwarding needed)
--   <D-s>  Mac / IDEA-style (Ghostty / Wezterm with Kitty Keyboard Protocol)
--   Both work in normal AND insert mode — insert mode stays in insert after save.
map({ "n", "v", "i" }, "<C-s>", "<cmd>silent! write<CR><Esc>", { desc = "Save file" })
map({ "n", "v", "i" }, "<D-s>", "<cmd>silent! write<CR><Esc>", { desc = "Save file (Cmd+S)" })
-- Save ALL open buffers
map("n",                "<D-A-s>", "<cmd>silent! wall<CR>",      { desc = "Save all" })

-- Comment line / block (uses LazyVim's Comment.nvim default).
map({ "n", "v" }, "<D-/>", "gcc", { remap = true, desc = "Toggle line comment" })
map({ "n", "v" }, "<D-A-/>", "gbc", { remap = true, desc = "Toggle block comment" })

-- Move line up/down (Alt+Shift in IDEA).
map("n", "<A-S-Up>",   "<cmd>m .-2<CR>==",      { desc = "Move line up" })
map("n", "<A-S-Down>", "<cmd>m .+1<CR>==",      { desc = "Move line down" })
map("v", "<A-S-Up>",   ":m '<-2<CR>gv=gv",      { desc = "Move selection up" })
map("v", "<A-S-Down>", ":m '>+1<CR>gv=gv",      { desc = "Move selection down" })

-- Move statement (treesitter swap).
map("n", "<D-S-Up>", function()
  local ok, swap = pcall(require, "nvim-treesitter.textobjects.swap")
  if ok then swap.swap_previous("@function.outer") end
end, { desc = "Move statement up" })
map("n", "<D-S-Down>", function()
  local ok, swap = pcall(require, "nvim-treesitter.textobjects.swap")
  if ok then swap.swap_next("@function.outer") end
end, { desc = "Move statement down" })

-- Extend / shrink selection (treesitter incremental).
map("n", "<D-w>", function()
  local ok, sel = pcall(require, "nvim-treesitter.incremental_selection")
  if ok then sel.init_selection() end
end, { desc = "Extend selection" })
map("v", "<D-w>", function()
  local ok, sel = pcall(require, "nvim-treesitter.incremental_selection")
  if ok then sel.node_incremental() end
end, { desc = "Extend selection" })
map("v", "<D-S-w>", function()
  local ok, sel = pcall(require, "nvim-treesitter.incremental_selection")
  if ok then sel.node_decremental() end
end, { desc = "Shrink selection" })

-- Code actions / completion.
map({ "n", "v" }, "<A-CR>", vim.lsp.buf.code_action, { desc = "Code action (Quick Fix)" })
map("i", "<C-Space>", function()
  local ok, blink = pcall(require, "blink.cmp")
  if ok then blink.show() end
end, { desc = "Trigger completion" })
map({ "n", "i" }, "<D-p>", vim.lsp.buf.signature_help, { desc = "Parameter info" })
map({ "n", "v" }, "<D-A-l>", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Reformat code" })
map("n", "<D-A-o>", function()
  vim.lsp.buf.code_action({
    apply = true,
    context = { only = { "source.organizeImports" }, diagnostics = {} },
  })
end, { desc = "Optimize imports" })
map("n", "<D-n>", function()
  vim.lsp.buf.code_action({ context = { only = { "source.generate" }, diagnostics = {} } })
end, { desc = "Generate code" })

-- Live template expand (LuaSnip).
map({ "i", "s" }, "<D-j>", function()
  local ok, ls = pcall(require, "luasnip")
  if ok and ls.expand_or_jumpable() then ls.expand_or_jump() end
end, { desc = "Expand snippet" })

-- Surround with (uses mini.surround default 'sa' op).
map("v", "<D-A-t>", "sa", { remap = true, desc = "Surround selection (mini.surround)" })

-- ============================================================
-- (2) SEARCH
-- ============================================================
map("n", "<leader><space>", function() Snacks.picker.smart() end, { desc = "Search Everywhere" })
map("n", "<D-S-a>", function() Snacks.picker.commands() end, { desc = "Find Action" })
map("n", "<D-f>",   "/", { desc = "Find in file" })
map("n", "<D-r>",   ":%s/", { desc = "Replace in file" })
map("n", "<D-S-f>", function() Snacks.picker.grep() end, { desc = "Find in path" })
map("n", "<D-S-r>", "<cmd>Spectre<CR>", { desc = "Replace in path" })
map("n", "<D-g>",   "n", { desc = "Find next" })
map("n", "<D-S-g>", "N", { desc = "Find prev" })

-- ============================================================
-- (3) NAVIGATION
-- ============================================================
map("n", "<D-o>", function()
  Snacks.picker.lsp_workspace_symbols({
    filter = function(s) return s.kind == "Class" or s.kind == "Interface" or s.kind == "Struct" end,
  })
end, { desc = "Go to Class" })
map("n", "<D-S-o>", function() Snacks.picker.files() end,         { desc = "Go to File" })
map("n", "<D-A-o>", function() Snacks.picker.lsp_symbols() end,   { desc = "Go to Symbol" })
map("n", "<D-e>",   function() Snacks.picker.recent() end,        { desc = "Recent Files" })
map("n", "<D-S-e>", function() Snacks.picker.jumps() end,         { desc = "Recent Locations" })
map("n", "<D-l>",   ":",                                          { desc = "Go to Line" })
map("n", "<D-b>",   vim.lsp.buf.definition,                       { desc = "Go to Declaration" })
map("n", "<D-A-b>", vim.lsp.buf.implementation,                   { desc = "Go to Implementation" })
map("n", "<D-u>",   vim.lsp.buf.type_definition,                  { desc = "Go to Type / Super" })
map("n", "<D-[>",   "<C-o>",                                      { desc = "Navigate Back" })
map("n", "<D-]>",   "<C-i>",                                      { desc = "Navigate Forward" })
map("n", "<D-F12>", "<cmd>Outline<CR>",                           { desc = "File Structure" })
map("n", "<A-F7>",  function() Snacks.picker.lsp_references() end, { desc = "Find Usages (picker)" })
map("n", "<F2>",    "]d",                                          { desc = "Next error" })
map("n", "<S-F2>",  "[d",                                          { desc = "Previous error" })

-- Global LSP picker fallbacks for `gr` / `gI` / `gd` / `gy`.
-- The editor.snacks_picker extra installs these as BUFFER-LOCAL maps on LspAttach.
-- Before LSP attaches (e.g. immediately after opening a fresh file), pressing `gr`
-- falls through to vim's native `gr` (virtual-replace) and `gI` (insert at BOL).
-- Setting them globally guarantees the picker fires every time, regardless of
-- attach timing. Buffer-local maps from the extra still take precedence when set.
map("n", "gr", function() Snacks.picker.lsp_references() end,       { desc = "References (picker, global fallback)" })
map("n", "gI", function() Snacks.picker.lsp_implementations() end,  { desc = "Implementations (picker, global fallback)" })
map("n", "gy", function() Snacks.picker.lsp_type_definitions() end, { desc = "Type definitions (picker, global fallback)" })

-- ============================================================
-- (4) REFACTOR
-- ============================================================
map("n", "<S-F6>", vim.lsp.buf.rename, { desc = "Rename" })
map("n", "<C-t>",  vim.lsp.buf.code_action, { desc = "Refactor This" })

-- ============================================================
-- (5) RUN / DEBUG
-- ============================================================
-- IDEA's ⌃R / ⌃D conflict with vim core (⌃R = redo, ⌃D = scroll half-page down).
-- We keep the vim defaults and bind Run/Debug to F-keys (VSCode-style) + <leader>r* / <leader>d*.
map("n", "<F5>",   function() require("dap").continue() end,          { desc = "Debug / Continue" })
map("n", "<leader>rr", function()
  local ok, ov = pcall(require, "overseer")
  if ok then ov.run_template() end
end, { desc = "Run (overseer)" })
map("n", "<F8>",   function() require("dap").step_over() end,         { desc = "Step Over" })
map("n", "<F7>",   function() require("dap").step_into() end,         { desc = "Step Into" })
map("n", "<S-F8>", function() require("dap").step_out() end,          { desc = "Step Out" })
map("n", "<A-F9>", function() require("dap").run_to_cursor() end,     { desc = "Run to Cursor" })
map("n", "<D-F8>", function() require("dap").toggle_breakpoint() end, { desc = "Toggle Breakpoint" })
map("n", "<A-F8>", function() require("dapui").eval(nil, { enter = true }) end, { desc = "Evaluate Expression" })
map("n", "<D-F2>", function() require("dap").terminate() end,         { desc = "Stop debugging" })

-- ============================================================
-- (6) VCS
-- ============================================================
map("n", "<D-k>",   "<cmd>Neogit<CR>",                       { desc = "Commit (Neogit)" })
map("n", "<D-S-k>", "<cmd>Neogit push<CR>",                  { desc = "Push" })
map("n", "<D-t>",   "<cmd>!git pull --rebase<CR>",           { desc = "Update Project (pull --rebase)" })
map("n", "<C-v>",   "<cmd>LazyGit<CR>",                      { desc = "VCS popup (lazygit)" })
map("n", "<C-S-v>", function()
  local ok, h = pcall(require, "yanky.history")
  if ok then h.open() end
end, { desc = "Paste history" })

-- ============================================================
-- (7) TOOL WINDOWS
-- ============================================================
map("n", "<D-1>",   function() Snacks.explorer() end,                  { desc = "Tool window: Project" })
map("n", "<D-2>",   "<cmd>Grapple toggle_tags<CR>",                    { desc = "Tool window: Bookmarks" })
map("n", "<D-3>",   "<cmd>Trouble qflist toggle<CR>",                  { desc = "Tool window: Find results" })
map("n", "<D-4>",   "<cmd>OverseerToggle<CR>",                         { desc = "Tool window: Run" })
map("n", "<D-5>",   function() require("dapui").toggle() end,          { desc = "Tool window: Debug" })
map("n", "<D-6>",   "<cmd>Trouble diagnostics toggle<CR>",             { desc = "Tool window: Problems" })
map("n", "<D-7>",   "<cmd>Outline<CR>",                                { desc = "Tool window: Structure" })
map("n", "<D-8>",   "<cmd>DBUIToggle<CR>",                             { desc = "Tool window: Database" })
map("n", "<D-9>",   "<cmd>Neogit<CR>",                                 { desc = "Tool window: Git" })
map("n", "<A-F12>", function() Snacks.terminal() end,                  { desc = "Tool window: Terminal" })
map("n", "<D-S-F12>", function()
  local ok, edgy = pcall(require, "edgy")
  if ok then edgy.toggle() end
end, { desc = "Hide / restore all tool windows" })

-- Leader-key fallbacks for tool windows (terminal-agnostic).
-- Use these if your terminal doesn't forward Cmd+digit.
-- <leader> = <Space>; <leader>1-4 are taken by grapple bookmarks, so we use letters here.
map("n", "<leader>oe", function() Snacks.explorer() end,            { desc = "Tool: Explorer" })
map("n", "<leader>oo", "<cmd>Outline<CR>",                          { desc = "Tool: Structure (Outline)" })
map("n", "<leader>or", "<cmd>OverseerToggle<CR>",                   { desc = "Tool: Run / Tasks" })
map("n", "<leader>od", function() require("dapui").toggle() end,    { desc = "Tool: Debug UI" })
map("n", "<leader>op", "<cmd>Trouble diagnostics toggle<CR>",       { desc = "Tool: Problems" })
map("n", "<leader>oD", "<cmd>DBUIToggle<CR>",                       { desc = "Tool: Database" })
map("n", "<leader>og", "<cmd>Neogit<CR>",                           { desc = "Tool: Git (Neogit)" })
map("n", "<leader>ot", function() Snacks.terminal() end,            { desc = "Tool: Terminal" })
map("n", "<leader>oh", function()
  local ok, edgy = pcall(require, "edgy")
  if ok then edgy.toggle() end
end, { desc = "Tool: Hide / restore all" })

-- ============================================================
-- (8) TABS
-- ============================================================
map("n", "<C-Right>", "<cmd>BufferLineCycleNext<CR>",                  { desc = "Next tab" })
map("n", "<C-Left>",  "<cmd>BufferLineCyclePrev<CR>",                  { desc = "Previous tab" })
map("n", "<D-F4>",    "<cmd>bd<CR>",                                   { desc = "Close tab" })
map("n", "<D-S-]>",   "<cmd>BufferLineCycleNext<CR>",                  { desc = "Next tab (alt)" })
map("n", "<D-S-[>",   "<cmd>BufferLineCyclePrev<CR>",                  { desc = "Previous tab (alt)" })

-- ============================================================
-- (9) NOTES (Obsidian)
-- ============================================================
map("n", "<leader>nn", "<cmd>ObsidianNew<CR>",          { desc = "New note" })
map("n", "<leader>nd", "<cmd>ObsidianToday<CR>",        { desc = "Daily note" })
map("n", "<leader>nf", "<cmd>ObsidianQuickSwitch<CR>",  { desc = "Find note" })
map("n", "<leader>ns", "<cmd>ObsidianSearch<CR>",       { desc = "Search vault" })
map("n", "<leader>nt", "<cmd>ObsidianTags<CR>",         { desc = "Browse tags" })
map("n", "<leader>nl", "<cmd>ObsidianLink<CR>",         { desc = "Insert link" })
map("n", "<leader>nb", "<cmd>ObsidianBacklinks<CR>",    { desc = "Backlinks" })
map("n", "<leader>nT", "<cmd>ObsidianToggleCheckbox<CR>", { desc = "Toggle checkbox" })

-- (Avante AI keymaps removed — migrated to CodeCompanion. <leader>aa is now
--  bound by the codecompanion plugin spec itself in lua/plugins/ai.lua.)

-- ============================================================
-- (11) THEME TOGGLE
-- ============================================================
-- Quick day/night swap within the Rose Pine family.
-- Main (dark) ↔ Dawn (light) — both ship with the rose-pine plugin.
map("n", "<leader>uL", function()
  local current = vim.g.colors_name or ""
  if current:match("dawn") then
    vim.cmd("colorscheme rose-pine-main")
    vim.notify("Theme: Rose Pine Main (dark)", vim.log.levels.INFO)
  else
    vim.cmd("colorscheme rose-pine-dawn")
    vim.notify("Theme: Rose Pine Dawn (light)", vim.log.levels.INFO)
  end
end, { desc = "Theme: toggle dark / light (rose-pine)" })

-- ============================================================
-- (12) FONT LIVE PICKER (Neovide only)
-- ============================================================
-- Curated code-font list. Live preview works in Neovide (changes guifont).
-- In terminal nvim the font is owned by the terminal — picker shows a notice
-- with the line to paste into ~/.config/ghostty/config and reminds to restart.
local FONTS = {
  -- ─── italic 大小写都连笔（你想要的）─────────────────────────────
  { family = "VictorMono Nerd Font",     note = "★ Victor — italic 大小写**都**是花体连笔" },
  { family = "Cascadia Code NF",         note = "★ Cascadia — italic 大小写都连笔（2204+ 新版）" },
  -- ─── 整字符手写感（不分 regular/italic）─────────────────────────
  { family = "Monaspace Radon NF",       note = "★ Monaspace Radon — 整字符手写感，文艺向" },
  { family = "RecMonoCasual Nerd Font",  note = "★ Recursive Casual — 手写体最浓" },
  -- ─── 半连笔（小写连大写不连）────────────────────────────────────
  { family = "Maple Mono NF",            note = "Maple — italic 小写连，大写仅倾斜（current）" },
  { family = "RecMonoSmCasual Nerd Font",note = "Recursive Semicasual — 微微手写，更克制" },
  { family = "Monaspace Argon NF",       note = "Monaspace Argon — humanist 偏端正" },
  -- ─── 重连字符号合并（=> ≠ → 等）─────────────────────────────────
  { family = "Lilex Nerd Font",          note = "Lilex — 重 ligature，符号合并多（=> ≡ ≠）" },
  { family = "Liga Comic Mono",          note = "Liga Comic Mono — 漫画字体（自动加行距，避免太挤）",
    linespace = 4 },
  -- ─── 端正派（无连笔）─────────────────────────────────────────────
  { family = "GeistMono Nerd Font",      note = "Vercel Geist — minimal, modern" },
  { family = "CommitMono Nerd Font",     note = "Commit — 极致清晰、平衡" },
  { family = "MonaspiceNe Nerd Font",    note = "Monaspace Neon — geometric" },
  { family = "JetBrainsMono Nerd Font",  note = "JetBrains — IDE 标准" },
}

map("n", "<leader>uf", function()
  vim.ui.select(FONTS, {
    prompt = vim.g.neovide and "Pick font (live preview):" or "Pick font (Ghostty needs restart):",
    format_item = function(f) return string.format("%-26s  %s", f.family, f.note) end,
  }, function(choice)
    if not choice then return end
    if vim.g.neovide then
      -- Per-font tuning: thick fonts (e.g. Liga Comic Mono) declare extra
      -- linespace so they breathe; default is h16 / linespace 0.
      local size = choice.size or 16
      local ls   = choice.linespace or 0
      vim.o.guifont   = choice.family .. ":h" .. size
      vim.opt.linespace = ls
      vim.notify(
        ("Font → %s  (h%s, linespace=%d)"):format(choice.family, size, ls),
        vim.log.levels.INFO,
        { title = "guifont" }
      )
    else
      local snippet = "font-family = " .. choice.family
      vim.fn.setreg("+", snippet)
      vim.notify(
        "Terminal mode — copied to clipboard:\n  " .. snippet .. "\n\nPaste into ~/.config/ghostty/config (replace the existing first font-family line), then ⌘Q + reopen Ghostty.",
        vim.log.levels.INFO,
        { title = "Font picker", timeout = 8000 }
      )
    end
  end)
end, { desc = "Font: pick (live in Neovide, copy-snippet in terminal)" })

-- ============================================================
-- (12b) NEOVIDE FONT ZOOM (Cmd+= / Cmd+- / Cmd+0)
-- ============================================================
-- Neovide has a native scale factor (`vim.g.neovide_scale_factor`); 1.0 is
-- the configured guifont size, anything else is a multiplier. We bind:
--   Cmd+=  / Cmd++ → zoom in   (+10%)
--   Cmd+-          → zoom out  (-10%)
--   Cmd+0          → reset to 100%
-- Bound in normal/insert/visual/terminal so it works mid-edit.
-- In kitty (terminal nvim), the same keys are intercepted by kitty itself
-- (see kitty.conf `change_font_size`), so this keymap only fires in Neovide.
if vim.g.neovide then
  local function scale(delta)
    local s = (vim.g.neovide_scale_factor or 1.0) + delta
    s = math.max(0.4, math.min(3.0, s))
    vim.g.neovide_scale_factor = s
    vim.notify(("Neovide scale → %d%%"):format(math.floor(s * 100 + 0.5)),
      vim.log.levels.INFO, { title = "Zoom" })
  end
  for _, mode in ipairs({ "n", "i", "v", "t" }) do
    map(mode, "<D-=>", function() scale( 0.10) end, { desc = "Zoom in" })
    map(mode, "<D-+>", function() scale( 0.10) end, { desc = "Zoom in (Shift+=)" })
    map(mode, "<D-->", function() scale(-0.10) end, { desc = "Zoom out" })
    map(mode, "<D-0>", function()
      vim.g.neovide_scale_factor = 1.0
      vim.notify("Neovide scale → 100%", vim.log.levels.INFO, { title = "Zoom" })
    end, { desc = "Reset zoom" })
  end
end

-- ============================================================
-- (13) NEOVIDE CURSOR VFX PICKER (Neovide only)
-- ============================================================
-- Cycle through the 7 cursor particle effects to find one you like.
-- Effect changes apply instantly; pick "" (none) to turn it off.
local VFX_MODES = {
  { mode = "pixiedust",  note = "sparkly trail (current — elegant)" },
  { mode = "ripple",     note = "water ripple (subtle)" },
  { mode = "wireframe",  note = "geometric wireframe" },
  { mode = "railgun",    note = "energy beam shot" },
  { mode = "torpedo",    note = "torpedo trail" },
  { mode = "sonicboom",  note = "sonic boom blast" },
  { mode = "",           note = "none (clean, no particles)" },
}

map("n", "<leader>uV", function()
  if not vim.g.neovide then
    vim.notify("Cursor VFX requires Neovide (terminal can't render particles).", vim.log.levels.WARN)
    return
  end
  vim.ui.select(VFX_MODES, {
    prompt = "Cursor VFX (live preview):",
    format_item = function(v)
      local label = (v.mode == "" and "<none>") or v.mode
      return string.format("%-12s  %s", label, v.note)
    end,
  }, function(choice)
    if not choice then return end
    vim.g.neovide_cursor_vfx_mode = choice.mode
    vim.notify("Cursor VFX → " .. (choice.mode == "" and "<none>" or choice.mode), vim.log.levels.INFO)
  end)
end, { desc = "Neovide: pick cursor VFX mode" })

-- ============================================================
-- (14) PROJECT SWITCHER (with session save/restore)
-- ============================================================
-- IDEA-style "Open Recent Project": save the current project's session,
-- jump to the chosen project's directory, close all buffers, then load
-- that project's session if one exists.
--
-- <leader>fp keeps the lighter Snacks default behaviour (just change cwd).
-- <leader>P  is the full switch — recommended for daily project hopping.
map("n", "<leader>P", function()
  Snacks.picker.projects({
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      local target = item.file or item.cwd or item.path
      if not target or target == "" then
        vim.notify("No project path on this entry", vim.log.levels.WARN)
        return
      end
      -- Save current state
      local persist_ok, persist = pcall(require, "persistence")
      if persist_ok then pcall(persist.save) end
      -- Switch directory
      vim.cmd("cd " .. vim.fn.fnameescape(target))
      -- Close all buffers
      vim.cmd("silent! %bdelete")
      -- Restore target project's session if it has one
      if persist_ok then pcall(persist.load) end
      vim.notify("Project → " .. target, vim.log.levels.INFO)
    end,
  })
end, { desc = "Switch project (save + restore session)" })

-- ============================================================
-- (15) IMAGE / DIAGRAM DEBUG
-- ============================================================
-- Print everything we know about image rendering: env, loaded plugins,
-- backend choice, CLI tools available. Run it then paste the notification.
map("n", "<leader>uI", function()
  local image_ok, image = pcall(require, "image")
  local diagram_ok = pcall(require, "diagram")
  local lines = {
    "=== Image / Diagram Debug ===",
    "GUI / TUI:",
    "  vim.g.neovide      = " .. tostring(vim.g.neovide),
    "  TERM_PROGRAM       = " .. tostring(vim.env.TERM_PROGRAM),
    "  TERM               = " .. tostring(vim.env.TERM),
    "Plugins:",
    "  image.nvim loaded  = " .. tostring(image_ok),
    "  diagram.nvim loaded= " .. tostring(diagram_ok),
  }
  if image_ok and image and image.state then
    table.insert(lines, "  image backend      = " .. tostring(image.state.backend and image.state.backend.name or "?"))
    table.insert(lines, "  image processor    = " .. tostring(image.state.processor and image.state.processor.name or "?"))
  end
  table.insert(lines, "CLIs:")
  table.insert(lines, "  magick             = " .. (vim.fn.executable("magick") == 1 and "yes" or "MISSING"))
  table.insert(lines, "  mmdc               = " .. (vim.fn.executable("mmdc") == 1 and "yes" or "MISSING"))
  table.insert(lines, "  plantuml           = " .. (vim.fn.executable("plantuml") == 1 and "yes" or "MISSING"))
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Image Debug", timeout = 30000 })
  print(table.concat(lines, "\n"))
end, { desc = "Image: print debug info" })

-- ============================================================
-- (16) CD-TO-HERE + REFRESH LEFT TREE
-- ============================================================
-- In a `:term` buffer, the shell's `cd` does NOT propagate to Neovim's cwd —
-- so `:Neotree dir=.` or `Snacks.explorer()` keeps showing the OLD project root.
-- This keymap reads the shell's true cwd (via `lsof` on the term job pid),
-- runs `:tcd` to it, then refreshes the left sidebar tree (Snacks.explorer,
-- and neo-tree too if it happens to be open).
--
-- In a normal file buffer it falls back to the file's directory.
local function resolve_target_dir()
  if vim.bo.buftype == "terminal" then
    local chan = vim.b.terminal_job_id
    if chan then
      local pid = vim.fn.jobpid(chan)
      if pid and pid > 0 then
        local out = vim.fn.systemlist({ "lsof", "-a", "-p", tostring(pid), "-d", "cwd", "-Fn" })
        for _, line in ipairs(out) do
          if line:sub(1, 1) == "n" then
            local p = line:sub(2)
            if p ~= "" and vim.fn.isdirectory(p) == 1 then return p end
          end
        end
      end
    end
  end
  local f = vim.api.nvim_buf_get_name(0)
  if f ~= "" then
    local d = vim.fn.fnamemodify(f, ":p:h")
    if vim.fn.isdirectory(d) == 1 then return d end
  end
  return nil
end

local function neotree_is_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then return true end
  end
  return false
end

map("n", "<leader>cw", function()
  local target = resolve_target_dir()
  if not target then
    vim.notify("无法确定目标目录（不是 term 也不是文件 buffer）", vim.log.levels.WARN)
    return
  end
  vim.cmd("tcd " .. vim.fn.fnameescape(target))
  pcall(function() Snacks.explorer({ cwd = target }) end)
  if neotree_is_open() then
    pcall(vim.cmd, "Neotree dir=" .. vim.fn.fnameescape(target))
  end
  vim.notify("CWD → " .. target, vim.log.levels.INFO)
end, { desc = "CD to here & refresh left tree" })

-- Remove a few LazyVim defaults that conflict with our IDEA mappings.
del("n", "<leader>l") -- avoid clash with <D-l>
