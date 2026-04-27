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

-- ============================================================
-- (10) AVANTE (AI)
-- ============================================================
map({ "n", "v" }, "<leader>aa", function()
  local ok, api = pcall(require, "avante.api")
  if ok then api.ask() end
end, { desc = "Avante: ask" })
map("v", "<leader>ae", function()
  local ok, api = pcall(require, "avante.api")
  if ok then api.edit() end
end, { desc = "Avante: edit selection" })
map("n", "<leader>ar", function()
  local ok, api = pcall(require, "avante.api")
  if ok then api.refresh() end
end, { desc = "Avante: refresh" })

-- ============================================================
-- (11) THEME TOGGLE
-- ============================================================
-- Quick day/night swap between Catppuccin Mocha (dark) and Catppuccin Latte (light).
-- Both flavors share the same plugin → no extra install, integrations identical.
map("n", "<leader>uL", function()
  local current = vim.g.colors_name or ""
  if current:match("latte") then
    vim.cmd("colorscheme catppuccin-mocha")
    vim.notify("Theme: Catppuccin Mocha (dark)", vim.log.levels.INFO)
  else
    vim.cmd("colorscheme catppuccin-latte")
    vim.notify("Theme: Catppuccin Latte (light)", vim.log.levels.INFO)
  end
end, { desc = "Theme: toggle dark / light" })

-- ============================================================
-- (12) FONT LIVE PICKER (Neovide only)
-- ============================================================
-- Curated code-font list. Live preview works in Neovide (changes guifont).
-- In terminal nvim the font is owned by the terminal — picker shows a notice
-- with the line to paste into ~/.config/ghostty/config and reminds to restart.
local FONTS = {
  { family = "Maple Mono NF",            note = "current — modern, CJK-friendly, beautiful italic" },
  { family = "VictorMono Nerd Font",     note = "elegant cursive italic — best with rose-pine" },
  { family = "GeistMono Nerd Font",      note = "Vercel — clean, minimal, modern" },
  { family = "CommitMono Nerd Font",     note = "ultra-readable, balanced spacing" },
  { family = "MonaspiceNe Nerd Font",    note = "GitHub Monaspace Neon — geometric" },
  { family = "JetBrainsMono Nerd Font",  note = "IDE standard — neutral, safe" },
}

map("n", "<leader>uf", function()
  vim.ui.select(FONTS, {
    prompt = vim.g.neovide and "Pick font (live preview):" or "Pick font (Ghostty needs restart):",
    format_item = function(f) return string.format("%-26s  %s", f.family, f.note) end,
  }, function(choice)
    if not choice then return end
    if vim.g.neovide then
      vim.o.guifont = choice.family .. ":h15.5"
      vim.notify("Font → " .. choice.family, vim.log.levels.INFO)
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

-- Remove a few LazyVim defaults that conflict with our IDEA mappings.
del("n", "<leader>l") -- avoid clash with <D-l>
