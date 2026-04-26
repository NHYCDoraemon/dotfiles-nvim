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

  -- In-buffer markdown rendering.
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
    ft = { "markdown", "Avante" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      preview = {
        modes = { "n", "no", "c" },
        hybrid_modes = { "i" },
        debounce = 50,
        callbacks = {
          on_enable = function(_, win) vim.wo[win].conceallevel = 2 end,
        },
      },
      markdown = {
        headings = { shift_width = 0 },
        list_items = { enable = true },
        code_blocks = { style = "language", language_direction = "right", min_width = 60 },
        tables = { use_virt_lines = true },
      },
      markdown_inline = {
        checkboxes = { enable = true },
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

  -- Hide LSP diagnostics on markdown buffers (marksman & friends still attach
  -- for go-to / completion / hover, but no inline error/warn squiggles).
  -- Also overrides LazyVim's default `vim.opt_local.spell = true` on markdown,
  -- which was the main source of red wavy lines under every non-dictionary word.
  {
    "neovim/nvim-lspconfig",
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        group = vim.api.nvim_create_augroup("UserMarkdownQuiet", { clear = true }),
        callback = function(args)
          vim.diagnostic.enable(false, { bufnr = args.buf })
          vim.opt_local.spell = false   -- override LazyVim's wrap_spell autocmd
        end,
      })
    end,
  },
}
