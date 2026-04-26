-- outline.nvim — file Structure panel (IDEA-style on the right edge).
-- LazyVim's `editor.outline` extra installs the plugin; we override its options here.
return {
  {
    "hedyhli/outline.nvim",
    -- Auto-open Outline on first LSP attach so it's already there when you open
    -- a code file. The hook fires once per nvim session; subsequent file opens
    -- don't re-trigger (Outline tracks the active buffer automatically).
    init = function()
      local opened = false
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserOutlineAutoOpen", { clear = true }),
        callback = function()
          if opened then return end
          opened = true
          vim.schedule(function()
            -- `Outline!` opens without focusing — keeps cursor in the editor.
            pcall(vim.cmd, "Outline!")
          end)
        end,
      })
    end,
    opts = {
      outline_window = {
        position = "right",
        width = 35,
        relative_width = false,
        focus_on_open = false,  -- don't steal focus when auto-opening
        auto_close = false,
        auto_jump = false,
      },
      outline_items = {
        show_symbol_details = true,
        show_symbol_lineno = false,
        highlight_hovered_item = true,
        auto_set_cursor = true,
      },
      -- All symbols expanded by default (no auto-fold). Match IDEA's Structure tree.
      symbol_folding = {
        autofold_depth = 99,
        auto_unfold = {
          hovered = true,
          only = true,
        },
        markers = { "", "" },
      },
      preview_window = {
        auto_preview = false,
        border = "rounded",
      },
      keymaps = {
        show_help = "?",
        close = { "<Esc>", "q" },
        goto_location = "<CR>",
        peek_location = "o",
        goto_and_close = "<S-CR>",
        restore_location = "<C-g>",
        hover_symbol = "K",
        toggle_preview = "P",
        rename_symbol = "r",
        code_actions = "a",
        fold = "h",
        unfold = "l",
        fold_toggle = "<Tab>",
        fold_toggle_all = "<S-Tab>",
        fold_all = "W",
        unfold_all = "E",
        fold_reset = "R",
      },
    },
  },
}
