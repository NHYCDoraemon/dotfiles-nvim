-- Persist the active colorscheme across nvim restarts.
--
-- Every time a colorscheme is applied (via <leader>uC picker, <leader>uL
-- toggle, or manually), an autocommand writes its name to a state file.
-- At startup, if that file exists, LazyVim reads it as the initial default —
-- otherwise it falls back to rose-pine-dawn.
--
-- State file: ~/.local/state/nvim/colorscheme.txt

local M = {}

M.state_dir = vim.fn.stdpath("state")
M.state_file = M.state_dir .. "/colorscheme.txt"

--- Return the last-used colorscheme, or the default if never saved.
function M.read()
  local f = io.open(M.state_file, "r")
  if not f then return nil end
  local name = f:read("*l")
  f:close()
  if name and name ~= "" and pcall(vim.cmd, "colorscheme " .. name) then
    -- Validate: the colorscheme must actually be available (plugin loaded).
    -- pcall catches 'E185: Cannot find color scheme'.
    -- If the plugin was removed or renamed, fall through to default.
    return name
  end
  return nil
end

--- Save the current colorscheme name to the state file (called by autocommand).
function M.save()
  vim.fn.mkdir(M.state_dir, "p")
  local name = vim.g.colors_name or ""
  if name == "" then return end
  local f = io.open(M.state_file, "w")
  if f then
    f:write(name .. "\n")
    f:close()
  end
end

-- Register a ColorScheme autocommand that fires AFTER the colorscheme has
-- been loaded, so vim.g.colors_name is already updated.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("ColorschemePersist", { clear = true }),
  pattern = "*",
  callback = M.save,
})

return M
