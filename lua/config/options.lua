-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Use basedpyright instead of pyright (LazyVim Python extra reads this at module-load).
vim.g.lazyvim_python_lsp = "basedpyright"

local opt = vim.opt

-- IDEA-style window chrome.
opt.cmdheight = 0           -- hide cmdline when not in use; noice will float it
opt.laststatus = 3          -- one global statusline (cleaner)
opt.showtabline = 0         -- no top tab bar (bufferline disabled; read-focused)
opt.scrolloff = 8           -- keep 8 lines of context above/below cursor
opt.sidescrolloff = 12
opt.signcolumn = "yes:1"    -- always show sign column to prevent jitter
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.cursorlineopt = "number,line"

-- Cursor: shape per mode + slow breathing blink. Combined with
-- vim.g.neovide_cursor_smooth_blink = true (set later in this file),
-- blinkon/blinkoff transitions become smooth fades — actual breathing
-- rather than abrupt on/off.
--   blinkwait1000  pause 1s before first blink (ergonomic when typing)
--   blinkon1000    fade-up to fully visible over 1s
--   blinkoff800    fade-down to invisible over 0.8s
-- ~1.8s total cycle — closer to a calm breathing rhythm than a heartbeat.
opt.guicursor = table.concat({
  "n-v-c:block",                 -- normal/visual/cmd: block
  "i-ci-ve:ver25",               -- insert/cmd-insert/visual-exclusive: vertical bar (25% width)
  "r-cr:hor20",                  -- replace/cmd-replace: horizontal bar (20% height)
  "o:hor50",                     -- operator-pending: bigger horizontal
  "a:blinkwait1000-blinkon1000-blinkoff800-Cursor/lCursor",
  "sm:block-blinkwait175-blinkoff150-blinkon175",
}, ",")
-- Smart soft-wrap: long lines visually wrap at word boundaries (linebreak),
-- the wrapped portion preserves the original indent (breakindent), and a
-- subtle ↪ marker shows where wrap occurred. File content is NOT modified —
-- this is purely visual.
opt.wrap = true
opt.linebreak = true
opt.breakindent = true
opt.showbreak = "↪ "
opt.colorcolumn = "100"      -- thin vertical line at column 100 (line-width hint)

-- Pretty diagnostic icons (replaces default E/W/I/H letters in the gutter
-- and on the satellite scrollbar). Theme controls the colors via
-- DiagnosticSign* highlight groups.
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "✘",
      [vim.diagnostic.severity.WARN]  = "⚠",
      [vim.diagnostic.severity.INFO]  = "●",
      [vim.diagnostic.severity.HINT]  = "◆",
    },
  },
})

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
  -- Font: JetBrainsMono Nerd Font Propo — IDEA's own font, so rendering/weight
  -- matches IDEA. It ships a REAL italic face, so italics (comments / keywords /
  -- static & abstract members) actually render in Neovide — Neovide does NOT
  -- synthesize oblique for fonts that lack one (which is why Liga Comic Mono,
  -- our earlier font, showed no italics). "Propo" = proportional Nerd Font icon
  -- glyphs (the code text stays monospaced; only icons are proportional).
  -- Single family (no comma fallback) — Neovide's guifont parser sometimes
  -- treats a comma-separated string as one missing name and falls back to the
  -- system default.
  -- Browse / change interactively with `<leader>uf` (FONTS picker in keymaps.lua).
  vim.o.guifont = "JetBrainsMono Nerd Font Propo:h16"
  -- 4px linespace for breathing room (was tuned for Comic Mono; fine for
  -- Cascadia too — lower it toward 2 if lines feel too loose).
  vim.opt.linespace = 4
  -- CJK characters use a dedicated font slot — `guifont` fallback chains are
  -- buggy in Neovide (see comment above), but `guifontwide` is a separate
  -- option built specifically for East Asian double-width chars.
  vim.o.guifontwide = "Source Han Sans VF:h16"

  -- Window chrome: fully frameless (no title bar / traffic-light buttons).
  -- IMPORTANT: on macOS this `vim.g.neovide_frame` is IGNORED — it's read
  -- after nvim starts, by which point the NSWindow already exists. The frame
  -- is actually controlled by ~/.config/neovide/config.toml (`frame = "none"`),
  -- which Neovide reads at process startup before creating the window.
  -- This line is kept for documentation / non-macOS platforms only.
  vim.g.neovide_frame          = "buttonless"

  vim.g.neovide_padding_top    = 8
  vim.g.neovide_padding_bottom = 8
  vim.g.neovide_padding_left   = 8
  vim.g.neovide_padding_right  = 8
  vim.g.neovide_remember_window_size = true

  -- macOS Cmd-key forwarding (so our IDEA <D-…> keymaps work natively).
  vim.g.neovide_input_use_logo = true
  vim.g.neovide_input_macos_option_key_is_meta = "only_left"

  -- Transparency / vibrancy: REMOVED.
  -- We tried opacity + window_blurred for a "frosted glass" feel but macOS
  -- native fullscreen breaks vibrancy (the fullscreen Space has no desktop
  -- behind it, so NSVisualEffectView renders as a flat gray box). Defaults
  -- (opacity = 1.0, window_blurred = false, floating_blur_amount = 2.0)
  -- look the same in windowed and fullscreen and don't have that issue.

  -- Smooth cursor: Neovide handles this natively at pixel level — no smear-cursor
  -- artifacts like in terminal mode. cursor_smooth_blink turns the
  -- guicursor blinkon/blinkoff (set in vim.opt.guicursor above) into
  -- smooth fades = breathing.
  -- animation_length 0.08 gives the cursor enough travel time for the
  -- trail/particles to actually be visible (0.05-0.06 felt instant — trail
  -- finished before the eye caught it). trail_size 1.0 = full smear length.
  vim.g.neovide_cursor_animation_length       = 0.08
  vim.g.neovide_cursor_trail_size             = 1.0   -- was 0.7: maximum smear
  vim.g.neovide_cursor_animate_in_insert_mode = true
  vim.g.neovide_cursor_smooth_blink           = true

  -- Cursor particle effect — pixie-dust trail behind cursor when moving.
  -- Modes: "" (off) | "railgun" | "torpedo" | "pixiedust" | "sonicboom"
  --        | "ripple" | "wireframe"
  -- particle_lifetime 2.5 + density 20 makes the trail visibly linger
  -- behind the cursor instead of vanishing in a frame.
  vim.g.neovide_cursor_vfx_mode              = "pixiedust"
  vim.g.neovide_cursor_vfx_particle_density  = 20.0   -- was 16
  vim.g.neovide_cursor_vfx_particle_speed    = 18.0
  vim.g.neovide_cursor_vfx_particle_lifetime = 2.5    -- was 1.8 — linger longer
  vim.g.neovide_cursor_vfx_opacity           = 240.0  -- was 220 — punchier

  -- Floating windows: rounded corners + soft drop shadow (IDE-style depth).
  vim.g.neovide_floating_corner_radius      = 0.8
  vim.g.neovide_floating_shadow             = true
  vim.g.neovide_floating_z_height           = 10
  vim.g.neovide_light_angle_degrees         = 45
  vim.g.neovide_light_radius                = 5

  -- Smooth scroll (Neovide's renderer makes this flicker-free).
  vim.g.neovide_scroll_animation_length     = 0.2
  -- WITHOUT this, Neovide's default `_far_lines = 1` skips animation for any
  -- scroll movement of more than 1 line — so <C-d>, gg, G, search jumps and
  -- mouse-wheel ticks all teleport instead of animating. 9999 = animate
  -- everything regardless of distance.
  vim.g.neovide_scroll_animation_far_lines  = 9999
  -- Window position animation (when nvim moves/resizes splits).
  vim.g.neovide_position_animation_length   = 0.10

  -- Refresh rate — capped at 30Hz on purpose.
  --
  -- The breathing cursor (smooth_blink + an always-on blinkon/blinkoff in
  -- guicursor) is a PERPETUAL fade animation that never settles, so Neovide
  -- never reaches its idle state — `_refresh_rate_idle` effectively never
  -- applies, and it would otherwise render at the full active rate forever,
  -- pegging a CPU core at 100%. Capping the active rate at 30 keeps the
  -- breathing effect while cutting the continuous render cost ~4x.
  -- (If you ever drop the breathing cursor, you can safely raise this back
  --  to 120 for ProMotion-smooth scrolling, since idle would then kick in.)
  vim.g.neovide_refresh_rate                = 30
  vim.g.neovide_refresh_rate_idle           = 30

  -- Quality-of-life polish.
  vim.g.neovide_hide_mouse_when_typing      = true
  vim.g.neovide_confirm_quit                = true
  vim.g.neovide_theme                       = "auto"  -- follow macOS dark/light

  -- Text rendering. contrast was 0.5 (added stroke weight) — that made glyphs
  -- read heavier than IDEA/JetBrains rendering, so it's dropped to 0.0 (neutral,
  -- no artificial weight). gamma stays neutral. NOTE: the bulk of the remaining
  -- "thickness" is the font itself (Liga Comic Mono is a heavy comic face); for
  -- a true IDEA look switch to a lighter font via <leader>uf (e.g. JetBrainsMono).
  vim.g.neovide_text_gamma                  = 0.0
  vim.g.neovide_text_contrast               = 0.0

end
