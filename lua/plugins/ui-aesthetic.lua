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

  -- Cursor motion smear/trail — DISABLED.
  --
  -- smear-cursor renders the trail using floating windows; in multi-window
  -- layouts (explorer / outline / dap-ui open) its position math leaks the
  -- trail into the wrong window, showing as flicker in side panels while
  -- the cursor is moving in the editor. Terminal grid-cell rendering can't
  -- reliably contain free-floating animations.
  --
  -- For real GUI-level cursor smoothness, run Neovide instead (native pixel
  -- rendering handles this perfectly with `cursor_animation_length` etc.).
  {
    "sphamba/smear-cursor.nvim",
    enabled = false,
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

  -- Code-action picker with inline diff preview.
  -- Replaces LazyVim's default <leader>ca. When you trigger a code action,
  -- each candidate now shows the actual diff it would produce, so you can
  -- pick by reading the change instead of by guessing from the action name.
  -- Use <leader>cF for the bulk "fix all" path (defined in keymaps.lua).
  {
    "aznhe21/actions-preview.nvim",
    event = "LspAttach",
    opts = {
      diff = { ctxlen = 3 },
      backend = { "snacks", "telescope", "nui" },
    },
    keys = {
      { "<leader>ca", function() require("actions-preview").code_actions() end,
        mode = { "n", "v" }, desc = "Code action (with diff preview)" },
    },
  },

  -- Snacks.dim: dim everything except the current scope (treesitter-aware).
  -- Lighter than zen-mode + twilight: stays inline, just fades surrounding
  -- code so the eye locks onto the function/block under cursor.
  -- Toggle with <leader>uD; auto-on can be set in opts but we keep it manual.
  {
    "folke/snacks.nvim",
    opts = { dim = { enabled = true } },
    keys = {
      { "<leader>uD", function() Snacks.dim() end, desc = "Toggle scope dim (snacks.dim)" },
    },
  },
}
