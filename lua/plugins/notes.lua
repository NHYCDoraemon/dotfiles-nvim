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

  -- (Snacks.image config removed — it was conflicting with lua/plugins/image.lua's
  --  `image = { enabled = false }` and producing the empty white frame around
  --  mermaid blocks. The single source of truth for image config is image.lua now.)

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
        -- `language` = just show language tag, no fake "preview frame" around the
        -- block. Border / min_width / pad were creating a visually empty box
        -- around mermaid blocks on Ghostty (since image render fails silently
        -- on the kitty graphics path) — easy to mistake for a broken popup.
        style = "language",
        position = "right",
        language_name = true,
        width = "block",
        left_pad = 0,
        right_pad = 0,
        min_width = 0,
        border = "none",
        highlight_inline = "RenderMarkdownCodeInline",
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

  -- cspell.nvim DISABLED — it depends on none-ls.nvim, but LazyVim has
  -- moved formatting/linting to conform.nvim + nvim-lint and warns when
  -- none-ls is loaded without the lazyvim.plugins.extras.lsp.none-ls extra.
  -- We weren't getting much value from cspell (already off for markdown/wiki).
  -- Remove this block entirely to clean up.
  { "davidmh/cspell.nvim",  enabled = false },
  { "nvimtools/none-ls.nvim", enabled = false },

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
