-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Disable LazyVim's default `vim.opt_local.spell = true` on markdown / text /
-- gitcommit / typst / plaintex. We delete the entire wrap_spell autogroup so
-- nothing in that registration order can fight us.
pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_wrap_spell")

-- Re-add only the wrap-line behavior (without the spell side-effect).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_text_wrap", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = false
  end,
})

-- Mute LSP diagnostics on markdown buffers (marksman / etc. still attach for
-- navigation & completion, but no inline error squiggles).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_markdown_no_diag", { clear = true }),
  pattern = "markdown",
  callback = function(args)
    vim.diagnostic.enable(false, { bufnr = args.buf })
  end,
})

-- `q` closes any floating window (goto-preview peek, LSP hover, dap-ui floats,
-- snacks help-style popups, etc.). LazyVim only binds q for a fixed list of
-- filetypes; this catches the rest by detecting `relative != ""` (= floating).
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  group = vim.api.nvim_create_augroup("user_q_closes_floats", { clear = true }),
  callback = function(args)
    local win = vim.api.nvim_get_current_win()
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" then
      vim.keymap.set("n", "q", "<cmd>close<CR>", {
        buffer = args.buf,
        silent = true,
        desc = "Close floating window",
      })
    end
  end,
})
