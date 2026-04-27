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

  -- markview.nvim DISABLED for markdown — render-markdown.nvim (already loaded
  -- as an Avante dependency) is now the primary markdown renderer with a more
  -- elegant default. Keeping markview spec around but inactive in case we want
  -- to re-enable it later. The `enabled = false` flag tells lazy.nvim to skip
  -- loading the plugin.
  {
    "OXY2DEV/markview.nvim",
    enabled = false,
    ft = { "markdown", "Avante" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>mt", "<cmd>RenderMarkdown toggle<cr>", desc = "Markdown: toggle render", ft = "markdown" },
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

  -- Inline image rendering for markdown — works in Neovide AND in Ghostty 1.3+
  -- (uses Kitty graphics protocol). `force = true` bypasses Snacks' DA1 terminal
  -- detection which sometimes fails to recognize Ghostty even though it supports
  -- the protocol. Combined with SNACKS_GHOSTTY=1 in options.lua, this guarantees
  -- mermaid blocks / images / math render inline.
  {
    "folke/snacks.nvim",
    opts = {
      image = {
        enabled = true,
        force = true,                -- skip detection, just try rendering
        doc = {
          enabled = true,
          inline = true,             -- render at the position they appear in the doc
          float  = true,             -- fall back to float if inline unsupported
          max_width  = 80,
          max_height = 32,
        },
        math = { enabled = true },   -- LaTeX rendering
        convert = {
          notify = true,
          command = "magick",
        },
      },
    },
  },

  -- Browser-based markdown preview — rock-solid mermaid / math / table rendering
  -- via the browser's native mermaid.js. Use this when Neovide's inline image
  -- pipeline misbehaves on a particular file, or for full-fidelity preview.
  --
  --   <leader>mp  → toggle preview (browser opens at localhost:8080-ish)
  --   <leader>mP  → stop preview server
  --
  -- Auto-refreshes on save; mermaid blocks render natively in the browser.
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
    init = function()
      vim.g.mkdp_filetypes        = { "markdown" }
      vim.g.mkdp_auto_close       = 0       -- don't close the tab when leaving md
      vim.g.mkdp_refresh_slow     = 0       -- update on every keystroke
      vim.g.mkdp_combine_preview  = 1       -- one tab for all md files
      vim.g.mkdp_theme            = "dark"  -- match our nvim theme
      vim.g.mkdp_preview_options  = {
        mkit = {},
        katex = {},
        uml = {},
        maid = {},                          -- mermaid (default cdn)
        disable_sync_scroll = 0,
        sync_scroll_type = "middle",
        hide_yaml_meta = 1,
        sequence_diagrams = {},
        flowchart_diagrams = {},
        content_editable = false,
        disable_filename = 0,
      }
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown: browser preview toggle", ft = "markdown" },
      { "<leader>mP", "<cmd>MarkdownPreviewStop<cr>",   desc = "Markdown: stop preview server",    ft = "markdown" },
    },
  },

  -- render-markdown.nvim — primary markdown renderer (Typora-esque).
  -- Originally pulled in as an Avante dependency; here we override its opts
  -- to give .md files a polished WYSIWYG-style render.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante" },
    opts = {
      file_types = { "markdown", "Avante" },

      -- Mode-aware rendering: render in normal/cmdline; reveal raw in insert.
      render_modes = { "n", "c", "t" },
      anti_conceal = { enabled = true },

      heading = {
        enabled = true,
        sign = false,                          -- no gutter sign (cleaner left margin)
        position = "overlay",
        icons = { "󰉫 ", "󰉬 ", "󰉭 ", "󰉮 ", "󰉯 ", "󰉰 " },  -- subtle bullet icons
        signs = { "󰫎 " },
        width = "block",                       -- background fill the line
        left_pad = 0,
        right_pad = 4,                         -- tail breathing room
        min_width = 0,
        border = false,
        above = " ",
        below = " ",
        backgrounds = {
          "RenderMarkdownH1Bg",
          "RenderMarkdownH2Bg",
          "RenderMarkdownH3Bg",
          "RenderMarkdownH4Bg",
          "RenderMarkdownH5Bg",
          "RenderMarkdownH6Bg",
        },
      },

      paragraph = { enabled = true, left_margin = 0 },

      code = {
        enabled = true,
        sign = false,
        style = "full",                         -- show language label + bg
        position = "left",
        language_pad = 0,
        language_name = true,
        disable_background = { "diff" },
        width = "block",
        left_pad = 2,
        right_pad = 2,
        min_width = 60,
        border = "thick",                       -- soft block border
        above = " ",
        below = " ",
        highlight_inline = "RenderMarkdownCodeInline",  -- inline `code` background
      },

      dash = { enabled = true, icon = "─", width = "full" },

      bullet = {
        enabled = true,
        icons = { "●", "○", "◆", "◇" },
        -- ordered_icons left at default — function signature varies between
        -- render-markdown versions; defaults render "1." "2." etc. cleanly.
        left_pad = 0,
        right_pad = 1,
      },

      checkbox = {
        enabled = true,
        position = "overlay",
        unchecked = { icon = "󰄱 ", highlight = "RenderMarkdownUnchecked" },
        checked   = { icon = "󰱒 ", highlight = "RenderMarkdownChecked" },
        custom = {
          todo = { raw = "[-]", rendered = "󰥔 ", highlight = "DiagnosticInfo" },
          important = { raw = "[!]", rendered = " ", highlight = "DiagnosticWarn" },
        },
      },

      quote = {
        enabled = true,
        icon = "▎",
        repeat_linebreak = true,                -- continue bar across paragraph wraps
        highlight = "RenderMarkdownQuote",
      },

      pipe_table = {
        enabled = true,
        preset = "round",                       -- rounded corner cells
        style  = "full",
        cell   = "padded",
      },

      link = {
        enabled = true,
        image = "󰥶 ",                            -- ![]() prefix
        email = "󰀓 ",
        hyperlink = " ",
        highlight = "RenderMarkdownLink",
        wiki = { icon = "󱗖 ", body = function() return nil end, highlight = "RenderMarkdownWikiLink" },
      },

      sign = { enabled = false },               -- no left-margin sign noise
    },

    keys = {
      { "<leader>mt", "<cmd>RenderMarkdown toggle<cr>", desc = "Markdown: toggle render", ft = "markdown" },
      { "<leader>me", "<cmd>RenderMarkdown enable<cr>", desc = "Markdown: enable render",  ft = "markdown" },
      { "<leader>md", "<cmd>RenderMarkdown disable<cr>", desc = "Markdown: disable render (raw)", ft = "markdown" },
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
