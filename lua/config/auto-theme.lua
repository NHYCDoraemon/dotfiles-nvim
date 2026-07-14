-- Automatic day/night colorscheme, driven by the macOS system appearance.
--
--   System Light  → rose-pine-dawn   (the daytime theme)
--   System Dark   → catppuccin-frappe (the night theme)
--
-- Wiring:
--   * colorscheme.lua calls M.apply_startup() as LazyVim's `colorscheme` opt, so
--     the correct theme is applied at STARTUP with no flash. (LazyVim invokes a
--     function colorscheme and expects the function itself to load it — it
--     ignores any return value.)
--   * M.setup() (called from autocmds.lua) re-checks on FocusGained, so flipping
--     the whole Mac to Dark and tabbing back into nvim flips the theme live.
--
-- Manual override: picking any theme yourself (<leader>uC picker, <leader>uL
-- dawn/main toggle, or :colorscheme) PAUSES auto-switching for the session, so
-- focus events won't yank your choice away. <leader>uA resumes auto (and applies
-- the appearance-appropriate theme immediately).
--
-- Detection note: `defaults read -g AppleInterfaceStyle` prints "Dark" only in
-- dark mode; in light mode the key doesn't exist and it errors on STDERR. We
-- read STDOUT only (2>/dev/null) and test for exactly "Dark".

local M = {}

M.day = "rose-pine-dawn"
M.night = "catppuccin-frappe"

M.paused = false   -- true once the user picks a theme manually this session
M.applying = false -- guard so our own :colorscheme isn't mistaken for a manual pick
M.current = nil    -- tracked mode target; avoids the rose-pine "colors_name" quirk
                   -- (`:colorscheme rose-pine-dawn` reports colors_name = "rose-pine")

--- @return boolean is the system currently in Dark mode
function M.is_dark()
  local out = vim.fn.trim(vim.fn.system("defaults read -g AppleInterfaceStyle 2>/dev/null"))
  return out == "Dark"
end

--- @return string the colorscheme the current appearance calls for
function M.desired()
  return M.is_dark() and M.night or M.day
end

--- Startup hook for LazyVim's `colorscheme` opt. Applies the appearance-appropriate
--- theme directly (LazyVim ignores the return value of a function colorscheme).
--- Errors propagate so LazyVim's habamax fallback can kick in.
function M.apply_startup()
  M.current = M.desired()
  M.applying = true
  local ok, err = pcall(vim.cmd.colorscheme, M.current)
  M.applying = false
  if not ok then error(err) end
end

--- Apply the appearance-appropriate theme. No-op if already on it (unless forced),
--- or if the user has manually overridden this session.
function M.apply(force)
  if M.paused and not force then return end
  local want = M.desired()
  if M.current == want and not force then return end
  M.current = want
  M.applying = true
  pcall(vim.cmd.colorscheme, want)
  M.applying = false
end

--- Manually toggle between the day and night themes, pausing auto for the session.
--- Direction is decided by `vim.o.background` (both themes set it: dawn→light,
--- catppuccin-frappe→dark) — NOT colors_name, which is "rose-pine" for every variant.
function M.toggle()
  M.paused = true
  local want = (vim.o.background == "dark") and M.day or M.night
  M.current = want
  M.applying = true
  pcall(vim.cmd.colorscheme, want)
  M.applying = false
  vim.notify("Theme: " .. want .. "  (auto paused — <leader>uA to resume)", vim.log.levels.INFO)
end

function M.setup()
  local grp = vim.api.nvim_create_augroup("AutoTheme", { clear = true })

  -- Re-evaluate whenever focus returns to nvim (cheap; user-paced).
  vim.api.nvim_create_autocmd("FocusGained", {
    group = grp,
    callback = function() M.apply(false) end,
  })

  -- Only AFTER startup do we start treating ColorScheme events as manual picks —
  -- otherwise LazyVim's own startup `colorscheme` application would falsely pause us.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = grp,
    callback = function()
      vim.schedule(function()
        vim.api.nvim_create_autocmd("ColorScheme", {
          group = grp,
          callback = function()
            if not M.applying then M.paused = true end
          end,
        })
      end)
    end,
  })

  -- Resume auto and re-apply immediately.
  vim.keymap.set("n", "<leader>uA", function()
    M.paused = false
    M.apply(true)
    vim.notify("Auto theme: ON (" .. (M.is_dark() and "dark · " .. M.night or "light · " .. M.day) .. ")",
      vim.log.levels.INFO)
  end, { desc = "Theme: resume auto day/night" })
end

return M
