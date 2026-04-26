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

  -- Animated indent line for current scope.
  {
    "nvim-mini/mini.indentscope",
    event = "BufReadPre",
    opts = {
      symbol = "│",
      options = { try_as_border = true },
      draw = {
        delay = 50,
        animation = function() return 8 end,
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "help", "alpha", "dashboard", "snacks_dashboard",
          "neo-tree", "Trouble", "trouble", "lazy", "mason",
          "notify", "toggleterm", "lazyterm", "Avante", "AvanteInput",
        },
        callback = function() vim.b.miniindentscope_disable = true end,
      })
    end,
  },
}
