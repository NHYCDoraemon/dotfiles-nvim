return {
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    ft = "markdown",
    cmd = {
      "ObsidianNew", "ObsidianToday", "ObsidianQuickSwitch",
      "ObsidianSearch", "ObsidianTags", "ObsidianBacklinks",
      "ObsidianLink", "ObsidianToggleCheckbox", "ObsidianOpen",
    },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      workspaces = {
        { name = "personal", path = "~/notes" },
      },
      daily_notes = {
        folder = "daily",
        date_format = "%Y-%m-%d",
        default_tags = { "daily" },
      },
      completion = {
        nvim_cmp = false,
        blink = true,
        min_chars = 2,
      },
      mappings = {},
      new_notes_location = "current_dir",
      preferred_link_style = "wiki",
      picker = { name = "snacks.pick" },
      ui = {
        enable = false, -- markview handles rendering instead
      },
    },
  },

  -- Typora-style in-buffer markdown rendering — hides ALL markup symbols and
  -- shows only the rendered visual. Toggle raw view with <leader>mt.
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
    ft = { "markdown", "Avante" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>mt", "<cmd>Markview Toggle<cr>", desc = "Markdown: toggle Typora render", ft = "markdown" },
      { "<leader>ms", "<cmd>Markview splitToggle<cr>", desc = "Markdown: toggle split render", ft = "markdown" },
    },
    opts = {
      preview = {
        modes = { "n", "no", "c" },          -- render in normal/operator/cmdline modes
        hybrid_modes = { "i" },              -- in insert: show raw markup at cursor line only
        linewise_hybrid_mode = true,         -- only the line being edited reveals raw syntax
        debounce = 25,                       -- snappier reactivity
        max_buf_lines = 1000,                -- skip rendering on huge files
        callbacks = {
          on_enable = function(_, win)
            vim.wo[win].conceallevel = 3     -- HIDE all markup characters
            vim.wo[win].concealcursor = "nc" -- keep concealed in normal/cmdline (Typora-style)
          end,
        },
      },

      markdown = {
        headings = {
          enable    = true,
          shift_width = 0,
          heading_1 = { style = "label", icon = "█ ", padding_left = " ", padding_right = " " },
          heading_2 = { style = "label", icon = "▌ ", padding_left = " ", padding_right = " " },
          heading_3 = { style = "label", icon = "▎ ", padding_left = " ", padding_right = " " },
          heading_4 = { style = "label", icon = "▏ ", padding_left = " ", padding_right = " " },
          heading_5 = { style = "label", icon = "▏ ", padding_left = " ", padding_right = " " },
          heading_6 = { style = "label", icon = "▏ ", padding_left = " ", padding_right = " " },
        },
        horizontal_rules = { enable = true },
        list_items = {
          enable = true,
          shift_width = 2,
          marker_minus = { add_padding = true, conceal = "•" },
          marker_plus  = { add_padding = true, conceal = "◆" },
          marker_star  = { add_padding = true, conceal = "★" },
        },
        block_quotes = { enable = true },
        code_blocks  = {
          style = "language",
          language_direction = "right",
          min_width = 70,
          pad_amount = 2,
          sign = false,
        },
        tables = { use_virt_lines = true },
      },

      markdown_inline = {
        checkboxes  = { enable = true },
        hyperlinks  = { enable = true },
        images      = { enable = true },
        emails      = { enable = true },
        inline_codes = { hl = "@text.literal" },
      },

      latex = { enable = true },
    },
  },

  -- Inline image rendering for markdown (works fully in Neovide; in Ghostty
  -- needs Kitty image protocol — Ghostty 1.3+ supports it).
  {
    "folke/snacks.nvim",
    opts = {
      image = {
        enabled = true,
        doc = {
          enabled = true,
          inline = true,
          float  = true,
          max_width  = 80,
          max_height = 32,
        },
        convert = {
          notify = true,
          command = "magick",  -- ImageMagick (we already install graphviz which pulls magick on some setups)
        },
      },
    },
  },

  -- camelCase-aware spell check (disabled on markdown / wiki — too noisy on prose).
  {
    "davidmh/cspell.nvim",
    dependencies = { "nvimtools/none-ls.nvim", "nvim-lua/plenary.nvim" },
    event = "BufReadPost",
    config = function()
      local null_ls = require("null-ls")
      local cspell = require("cspell")
      null_ls.setup({
        sources = {
          cspell.diagnostics.with({
            runtime_condition = function(params)
              -- Skip cspell entirely on markdown buffers.
              return params.ft ~= "markdown"
            end,
            diagnostics_postprocess = function(d) d.severity = vim.diagnostic.severity.HINT end,
          }),
          cspell.code_actions,
        },
      })
    end,
  },

  -- Silence markdown linters & LSP diagnostics on markdown / wiki files.
  -- Keeps marksman LSP attached for navigation/completion, just hides its diagnostics.
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = {} -- empty list = no markdownlint / vale / etc.
      return opts
    end,
  },

  -- (markdown spell + diagnostic muting moved to lua/config/autocmds.lua so it
  --  reliably runs after LazyVim's defaults — see that file.)
}
