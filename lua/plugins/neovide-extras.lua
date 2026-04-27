-- 5 plugins that especially shine with Neovide's pixel-level GUI rendering.
-- All work in terminal nvim too — Neovide just makes them prettier.
return {
  -- 1. Floating filename label in top-right of each window.
  --    Multi-split layouts get instantly readable; rounded GUI corners shine.
  {
    "b0o/incline.nvim",
    event = "BufReadPre",
    opts = {
      window = {
        margin = { vertical = 0, horizontal = 1 },
        padding = 1,
        placement = { horizontal = "right", vertical = "top" },
      },
      hide = {
        cursorline = false,
        focused_win = false,
        only_win = false,
      },
      -- Skip filetypes that have their own UI / chrome (Avante chat, dap-ui,
      -- outline, etc.) — incline's floating label otherwise overlaps them.
      ignore = {
        unlisted_buffers = true,
        floating_wins = true,
        filetypes = {
          "Avante", "AvanteInput", "AvanteSelectedFiles",
          "Outline", "snacks_layout_box", "snacks_dashboard",
          "trouble", "Trouble", "dap-repl", "dapui_console",
          "dapui_scopes", "dapui_breakpoints", "dapui_stacks", "dapui_watches",
          "neogit", "DiffviewFiles", "DiffviewFileHistory",
          "lazy", "mason", "help", "noice",
        },
      },
      render = function(props)
        local devicons = require("nvim-web-devicons")
        local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
        if filename == "" then filename = "[No Name]" end
        local ft_icon, ft_color = devicons.get_icon_color(filename)
        local modified = vim.bo[props.buf].modified
        return {
          ft_icon and { " ", ft_icon, " ", guifg = ft_color } or "",
          { filename, gui = modified and "bold,italic" or "bold" },
          modified and { " ●", guifg = "#f38ba8" } or "",
          " ",
        }
      end,
    },
  },

  -- 2. Right-side scrollbar with diagnostic / git / search markers.
  {
    "petertriho/nvim-scrollbar",
    event = "BufReadPost",
    dependencies = { "lewis6991/gitsigns.nvim" },
    opts = {
      handle = { color = "#403d52" },           -- rose-pine-friendly
      excluded_filetypes = {
        "dropbar_menu", "snacks_dashboard", "lazy", "mason", "TelescopePrompt",
        "neo-tree", "Outline", "trouble", "Avante", "AvanteInput",
      },
      marks = {
        Search = { color = "#f6c177" },
        Error  = { color = "#eb6f92" },
        Warn   = { color = "#f6c177" },
        Info   = { color = "#9ccfd8" },
        Hint   = { color = "#c4a7e7" },
        Misc   = { color = "#c4a7e7" },
        GitAdd = { color = "#31748f" },
        GitChange = { color = "#9ccfd8" },
        GitDelete = { color = "#eb6f92" },
      },
    },
    config = function(_, opts)
      require("scrollbar").setup(opts)
      require("scrollbar.handlers.gitsigns").setup()
    end,
  },

  -- 3. Highlight all occurrences of word under cursor.
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      delay = 200,
      large_file_cutoff = 2000,
      large_file_overrides = { providers = { "lsp" } },
      filetypes_denylist = {
        "dirvish", "fugitive", "alpha", "NvimTree", "lazy", "neogitstatus",
        "Trouble", "trouble", "lir", "Outline", "spectre_panel", "toggleterm",
        "DressingSelect", "TelescopePrompt", "snacks_dashboard", "Avante",
        "AvanteInput",
      },
    },
    config = function(_, opts)
      require("illuminate").configure(opts)
      vim.api.nvim_set_hl(0, "IlluminatedWordText",  { link = "Visual" })
      vim.api.nvim_set_hl(0, "IlluminatedWordRead",  { link = "Visual" })
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "Visual" })
    end,
    keys = {
      { "]]", function() require("illuminate").goto_next_reference(false) end, desc = "Next reference" },
      { "[[", function() require("illuminate").goto_prev_reference(false) end, desc = "Prev reference" },
    },
  },

  -- 4. Open files in current nvim from a child shell — git editor, etc.
  --    When `git commit` (run from :term) tries to spawn `nvim`, flatten
  --    intercepts and opens the buffer in the existing window. No nested nvim.
  {
    "willothy/flatten.nvim",
    lazy = false,
    priority = 1001,        -- must load before any terminal opens
    opts = {
      window = { open = "alternate" },   -- new buffer in alternate window
      callbacks = {
        should_block = function(argv)
          -- Block (= make the calling shell wait) for git editors only.
          return vim.tbl_contains(argv, "-b") or vim.tbl_contains(argv, "--block")
            or argv[#argv] and argv[#argv]:match("COMMIT_EDITMSG")
        end,
        post_open = function(bufnr, winnr, ft, is_blocking)
          if is_blocking then
            vim.bo[bufnr].bufhidden = "wipe"
            vim.api.nvim_create_autocmd("BufWipeout", {
              buffer = bufnr,
              once = true,
              callback = function() vim.api.nvim_input("<Esc>") end,
            })
          end
        end,
      },
    },
  },

  -- 5. Split / join code blocks via treesitter.
  {
    "Wansmer/treesj",
    keys = {
      { "<leader>cj", function() require("treesj").toggle() end, desc = "Code: split / join (treesitter)" },
      { "<leader>cJ", function() require("treesj").split() end,  desc = "Code: split" },
      { "<leader>ck", function() require("treesj").join() end,   desc = "Code: join" },
    },
    opts = {
      use_default_keymaps = false,
      max_join_length = 200,
      cursor_behavior = "hold",
    },
  },
}
