return {
  -- Core animation engine.
  {
    "nvim-mini/mini.animate",
    event = "VeryLazy",
    opts = function()
      local animate = require("mini.animate")
      return {
        -- Cursor animation disabled: it interferes with large jumps like `gg`/`G`/`%`/search.
        -- Smear-cursor.nvim handles the trailing-cursor effect instead.
        cursor = { enable = false },
        -- Scroll animation disabled: snacks.scroll (LazyVim default) already handles
        -- smooth scrolling. Two engines together cause treesitter-context flicker.
        scroll = { enable = false },
        resize = {
          enable = true,
          timing = animate.gen_timing.linear({ duration = 200, unit = "total" }),
        },
        open = {
          enable = true,
          timing = animate.gen_timing.linear({ duration = 200, unit = "total" }),
        },
        close = {
          enable = true,
          timing = animate.gen_timing.linear({ duration = 200, unit = "total" }),
        },
      }
    end,
  },

  -- Indent guides handled by snacks.indent (see plugins/snacks-indent.lua).
  -- mini.indentscope is disabled to avoid drawing two lines on top of each
  -- other on the current scope.
  {
    "nvim-mini/mini.indentscope",
    enabled = false,
  },
}
