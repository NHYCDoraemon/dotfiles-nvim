-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Use basedpyright instead of pyright (LazyVim Python extra reads this at module-load).
vim.g.lazyvim_python_lsp = "basedpyright"

local opt = vim.opt

-- IDEA-style window chrome.
opt.cmdheight = 0           -- hide cmdline when not in use; noice will float it
opt.laststatus = 3          -- one global statusline (cleaner)
opt.scrolloff = 8           -- keep 8 lines of context above/below cursor
opt.sidescrolloff = 12
opt.signcolumn = "yes:1"    -- always show sign column to prevent jitter
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.cursorlineopt = "number,line"
opt.wrap = false

-- Indent
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"

-- Persistence
opt.undofile = true
opt.undolevels = 10000
opt.swapfile = false
opt.backup = false

-- Visual polish
opt.termguicolors = true
opt.pumblend = 10
opt.pumheight = 12
opt.winminwidth = 5
opt.fillchars = {
  foldopen = "▾",
  foldclose = "▸",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ",
}

-- Neovim 0.11 rounded popup borders globally.
if vim.fn.has("nvim-0.11") == 1 then
  vim.o.winborder = "rounded"
end

-- Clipboard sharing with macOS.
opt.clipboard = "unnamedplus"

-- Faster which-key.
-- Key-sequence timeout. 300ms (LazyVim default) is too aggressive for multi-key
-- IDEA-style chords like <Space>oo / <Space>cs / gI — typing slightly slower
-- caused the second key to be processed standalone. 600ms is a safer middle.
opt.timeout = true
opt.timeoutlen = 600

-- ============================================================================
-- GUI nvim (Neovide) — only applies when running inside Neovide.
-- Terminal nvim ignores `vim.g.neovide` (which is unset there).
-- Ghostty's font config does NOT apply to Neovide; use vim's guifont here.
-- ============================================================================
if vim.g.neovide then
  -- Font: same family + size as Ghostty config so the visual is consistent.
  -- Single family (no comma fallback) — Neovide's guifont parser sometimes
  -- treats the whole comma-separated string as one missing font name and
  -- falls back to the system default. Maple Mono NF already includes all
  -- Nerd Font icon glyphs, so a fallback chain isn't needed.
  vim.o.guifont = "Maple Mono NF:h15.5"

  -- Window chrome
  vim.g.neovide_padding_top    = 8
  vim.g.neovide_padding_bottom = 8
  vim.g.neovide_padding_left   = 8
  vim.g.neovide_padding_right  = 8
  vim.g.neovide_remember_window_size = true

  -- macOS Cmd-key forwarding (so our IDEA <D-…> keymaps work natively).
  vim.g.neovide_input_use_logo = true
  vim.g.neovide_input_macos_option_key_is_meta = "only_left"

  -- Subtle transparency + floating-window blur (vibrancy effect).
  vim.g.neovide_transparency = 0.96
  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0

  -- Smooth cursor: Neovide handles this natively at pixel level — no smear-cursor
  -- artifacts like in terminal mode.
  vim.g.neovide_cursor_animation_length     = 0.07
  vim.g.neovide_cursor_trail_size           = 0.5
  vim.g.neovide_cursor_animate_in_insert_mode = true
  vim.g.neovide_cursor_smooth_blink         = true

  -- Smooth scroll (Neovide's renderer makes this flicker-free).
  vim.g.neovide_scroll_animation_length     = 0.2
end
