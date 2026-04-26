return {
  -- Floating cmdline + LSP-progress popups + message rerouting.
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    opts = {
      cmdline = {
        view = "cmdline_popup",
        format = {
          cmdline     = { pattern = "^:",        icon = "", lang = "vim" },
          search_down = { kind = "search",       pattern = "^/", icon = "/", lang = "regex" },
          search_up   = { kind = "search",       pattern = "^%?", icon = "?", lang = "regex" },
        },
      },
      messages = {
        enabled = true,
        view = "notify",
        view_search = "virtualtext",
      },
      popupmenu = { enabled = true, backend = "nui" },
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        progress = { enabled = true, view = "mini" },
        signature = { enabled = true },
        hover = { enabled = true, silent = true },
      },
      presets = {
        bottom_search = false,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = true,
        lsp_doc_border = true,
      },
      views = {
        cmdline_popup = {
          position = { row = "40%", col = "50%" },
          size = { width = 60, height = "auto" },
          border = { style = "rounded" },
          win_options = { winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" } },
        },
      },
    },
  },

  {
    "rcarriga/nvim-notify",
    opts = {
      timeout = 3000,
      max_height = function() return math.floor(vim.o.lines * 0.75) end,
      max_width  = function() return math.floor(vim.o.columns * 0.75) end,
      stages = "fade",
      render = "compact",
      top_down = false,
    },
  },

  -- Compact inline diagnostic display.
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    priority = 1000,
    opts = {
      preset = "modern",
      hi = { mixing_color = "Normal" },
      options = {
        show_source = true,
        throttle = 20,
        softwrap = 30,
        multilines = true,
        show_all_diags_on_cursorline = false,
      },
    },
    init = function()
      vim.diagnostic.config({ virtual_text = false, virtual_lines = false })
    end,
  },

  -- Colored matching brackets.
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "BufReadPost",
    config = function()
      local rd = require("rainbow-delimiters")
      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rd.strategy["global"],
          commonlisp = rd.strategy["local"],
        },
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        highlight = {
          "RainbowDelimiterRed", "RainbowDelimiterYellow", "RainbowDelimiterBlue",
          "RainbowDelimiterOrange", "RainbowDelimiterGreen", "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },

  -- Mode-aware cursor-line tint (NORMAL=blue, INSERT=green, etc.).
  {
    "mawkler/modicator.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.cursorline = true
      vim.o.number = true
      vim.o.termguicolors = true
    end,
    opts = {
      show_warnings = false,
      highlights = { defaults = { bold = true } },
      integration = { lualine = { enabled = true } },
    },
  },

  -- Cursor motion smear/trail.
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
      cursor_color = "none",
      stiffness = 0.7,
      trailing_stiffness = 0.55,
      distance_stop_animating = 0.5,
      hide_target_hack = false,
    },
  },

  -- Color value preview (#ff00ff swatches).
  {
    "brenoprata10/nvim-highlight-colors",
    event = "BufReadPost",
    opts = {
      render = "background",
      enable_named_colors = true,
      enable_tailwind = true,
    },
  },
}
