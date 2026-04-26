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
