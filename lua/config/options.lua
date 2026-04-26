-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

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
opt.timeout = true
opt.timeoutlen = 300
