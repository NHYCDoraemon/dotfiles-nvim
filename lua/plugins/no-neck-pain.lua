-- no-neck-pain.nvim — horizontal centering via empty padding buffers.
-- This is the asymmetry-free alternative to zen-mode for "I want my code
-- in the middle of the screen". Unlike zen-mode (which uses a floating
-- backdrop and exposes underlying buffer text on the sides), NNP creates
-- two empty scratch buffers as L/R padding — the sides are uniformly empty
-- regardless of what code is loaded.
--
-- Toggle: <leader>uN. The wrapper also hides chrome (line numbers,
-- signcolumn, cursorline, statusline, mode) on enable and restores them
-- on disable, so the result is "centered + zen-like" in one keystroke.
--
-- Safety: pressing `q` in a NNP padding buffer toggles NNP off (escapes
-- the dead-end scratch buffer). After toggling, focus is forced back to
-- the main code buffer so you don't land in the padding by accident.

local function toggle_nnp()
  vim.g._dora_nnp_active = not vim.g._dora_nnp_active
  vim.cmd("NoNeckPain")
  if vim.g._dora_nnp_active then
    vim.g._dora_nnp_saved = {
      number         = vim.o.number,
      relativenumber = vim.o.relativenumber,
      signcolumn     = vim.o.signcolumn,
      cursorline     = vim.o.cursorline,
      laststatus     = vim.o.laststatus,
      showmode       = vim.o.showmode,
    }
    vim.opt.number         = false
    vim.opt.relativenumber = false
    vim.opt.signcolumn     = "no"
    vim.opt.cursorline     = false
    vim.opt.laststatus     = 0
    vim.opt.showmode       = false
  else
    local s = vim.g._dora_nnp_saved or {}
    vim.opt.number         = s.number ~= nil and s.number or true
    vim.opt.relativenumber = s.relativenumber ~= nil and s.relativenumber or true
    vim.opt.signcolumn     = s.signcolumn or "yes"
    vim.opt.cursorline     = s.cursorline ~= nil and s.cursorline or true
    vim.opt.laststatus     = s.laststatus or 3
    vim.opt.showmode       = s.showmode ~= nil and s.showmode or true
  end

  -- After toggling, jump focus to a NON-NNP window. If the cursor happened
  -- to be in a padding buffer (or NNP put it there during enable), this
  -- moves it to a real code buffer. Iterate windows; pick the first whose
  -- buffer's filetype is not "no-neck-pain".
  vim.schedule(function()
    if vim.bo.filetype == "no-neck-pain" then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype ~= "no-neck-pain" then
          vim.api.nvim_set_current_win(win)
          return
        end
      end
    end
  end)
end

return {
  {
    "shortcuts/no-neck-pain.nvim",
    cmd = "NoNeckPain",
    keys = {
      { "<leader>uN", toggle_nnp, desc = "Centered zen (NoNeckPain + chrome off)" },
    },
    init = function()
      -- Escape hatch: in a NNP padding buffer, q closes the whole NNP.
      -- (The padding buffer is filetype "no-neck-pain"; without this, q
      -- starts a macro recording — confusing dead-end.)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "no-neck-pain",
        callback = function(args)
          vim.keymap.set("n", "q", toggle_nnp,
            { buffer = args.buf, desc = "Close NoNeckPain" })
          vim.keymap.set("n", "<Esc>", toggle_nnp,
            { buffer = args.buf, desc = "Close NoNeckPain" })
        end,
      })
    end,
    opts = {
      width = 100,
      autocmds = {
        enableOnVimEnter      = false,
        enableOnTabEnter      = false,
        reloadOnColorSchemeChange = true,
      },
      mappings = {
        enabled = false,
      },
      buffers = {
        setNames = false,
        bo = {
          filetype  = "no-neck-pain",
          buftype   = "nofile",
          bufhidden = "hide",
          buflisted = false,
          swapfile  = false,
        },
        wo = {
          cursorline    = false,
          cursorcolumn  = false,
          number        = false,
          relativenumber= false,
          foldenable    = false,
          list          = false,
        },
      },
    },
  },
}
