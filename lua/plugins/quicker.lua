-- A modern quickfix window (stevearc/quicker): prettier, resizable, and
-- editable — edit the qf list like a buffer and :w to apply changes back to the
-- files. Enhances the native quickfix automatically; nothing else is affected.
--   <leader>uq → toggle the quickfix window
return {
  {
    "stevearc/quicker.nvim",
    event = "FileType qf",
    keys = {
      { "<leader>uq", function() require("quicker").toggle() end, desc = "Toggle quickfix (quicker)" },
    },
    opts = {
      editable = true,
      opts = { number = true, relativenumber = false },
      highlight = { treesitter = true, lsp = true },
    },
  },
}
