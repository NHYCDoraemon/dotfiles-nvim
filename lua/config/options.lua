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
-- Force Snacks.image to enable Ghostty graphics protocol.
--
-- Snacks tries to auto-detect terminal capabilities by sending a DA1 (Device
-- Attributes) query and parsing the reply. Ghostty supports the Kitty graphics
-- protocol but its DA1 response doesn't always match Snacks' regex, so the
-- detection fails and Snacks falls back to "graphics not supported".
--
-- Setting SNACKS_GHOSTTY=1 in the environment overrides detection. We only
-- set it when we know we're actually in Ghostty (TERM_PROGRAM check).
-- ============================================================================
if vim.env.TERM_PROGRAM == "ghostty" then
  vim.env.SNACKS_GHOSTTY = "1"
end

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
  vim.g.neovide_opacity = 0.96  -- renamed from neovide_transparency in newer Neovide
  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0

  -- Smooth cursor: Neovide handles this natively at pixel level — no smear-cursor
  -- artifacts like in terminal mode.
  vim.g.neovide_cursor_animation_length     = 0.07
  vim.g.neovide_cursor_trail_size           = 0.5
  vim.g.neovide_cursor_animate_in_insert_mode = true
  vim.g.neovide_cursor_smooth_blink         = true

  -- Cursor particle effect — pixie-dust trail behind cursor when moving.
  -- Modes: "" (off) | "railgun" | "torpedo" | "pixiedust" | "sonicboom"
  --        | "ripple" | "wireframe"
  -- `pixiedust` is elegant + not distracting; cycle others via <leader>uV.
  vim.g.neovide_cursor_vfx_mode             = "pixiedust"
  vim.g.neovide_cursor_vfx_particle_density = 12.0
  vim.g.neovide_cursor_vfx_particle_speed   = 16.0
  vim.g.neovide_cursor_vfx_particle_lifetime = 1.5
  vim.g.neovide_cursor_vfx_opacity          = 200.0

  -- Floating windows: rounded corners + soft drop shadow (IDE-style depth).
  vim.g.neovide_floating_corner_radius      = 0.5
  vim.g.neovide_floating_shadow             = true
  vim.g.neovide_floating_z_height           = 10
  vim.g.neovide_light_angle_degrees         = 45
  vim.g.neovide_light_radius                = 5

  -- Smooth scroll (Neovide's renderer makes this flicker-free).
  vim.g.neovide_scroll_animation_length     = 0.2
  -- Window position animation (when nvim moves/resizes splits).
  vim.g.neovide_position_animation_length   = 0.15

  -- Refresh rate — match ProMotion (120Hz on M-series MacBook Pro / Studio
  -- Display Pro). Falls back fine on 60Hz panels. Lower idle rate saves
  -- battery when nothing is changing.
  vim.g.neovide_refresh_rate                = 120
  vim.g.neovide_refresh_rate_idle           = 30

  -- macOS-only: window background vibrancy ("blur the desktop behind us").
  vim.g.neovide_window_blurred              = true

  -- Quality-of-life polish.
  vim.g.neovide_hide_mouse_when_typing      = true
  vim.g.neovide_confirm_quit                = true
  vim.g.neovide_theme                       = "auto"  -- follow macOS dark/light

  -- Text rendering: subtle gamma + contrast tweaks for sharper glyphs on
  -- retina displays (defaults are conservative; 0.5 contrast gives strokes
  -- a touch more weight without going bold).
  vim.g.neovide_text_gamma                  = 0.0
  vim.g.neovide_text_contrast               = 0.5
end
