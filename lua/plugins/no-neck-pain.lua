-- no-neck-pain.nvim — horizontal centering via empty padding buffers.
-- This is the asymmetry-free alternative to zen-mode for "I want my code
-- in the middle of the screen". Unlike zen-mode (which uses a floating
-- backdrop and exposes underlying buffer text on the sides), NNP creates
-- two empty scratch buffers as L/R padding — the sides are uniformly empty
-- regardless of what code is loaded.
--
-- Toggle: <leader>uN. The wrapper function also hides chrome (line numbers,
-- signcolumn, cursorline) when enabling, and restores them on disable, so
-- the result is "centered + zen-like" in one keystroke.
return {
  {
    "shortcuts/no-neck-pain.nvim",
    cmd = "NoNeckPain",
    keys = {
      {
        "<leader>uN",
        function()
          -- Track state via vim.g (survives across reloads).
          vim.g._dora_nnp_active = not vim.g._dora_nnp_active
          vim.cmd("NoNeckPain")
          if vim.g._dora_nnp_active then
            -- Save then hide chrome.
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
            -- Restore.
            local s = vim.g._dora_nnp_saved or {}
            vim.opt.number         = s.number ~= nil and s.number or true
            vim.opt.relativenumber = s.relativenumber ~= nil and s.relativenumber or true
            vim.opt.signcolumn     = s.signcolumn or "yes"
            vim.opt.cursorline     = s.cursorline ~= nil and s.cursorline or true
            vim.opt.laststatus     = s.laststatus or 3
            vim.opt.showmode       = s.showmode ~= nil and s.showmode or true
          end
        end,
        desc = "Centered zen (NoNeckPain + chrome off)",
      },
    },
    opts = {
      width = 100,                              -- main buffer keeps 100 columns
      autocmds = {
        enableOnVimEnter      = false,
        enableOnTabEnter      = false,
        reloadOnColorSchemeChange = true,
      },
      mappings = {
        enabled = false,                        -- we wire our own keymap above
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
