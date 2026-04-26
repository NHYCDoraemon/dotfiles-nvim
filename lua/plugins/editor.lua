return {
  -- Label-based jump.
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      labels = "asdfghjklqwertyuiopzxcvbnm",
      label = { rainbow = { enabled = true, shade = 5 } },
      modes = {
        char = { enabled = true, jump_labels = true },
        search = { enabled = true },
      },
    },
    keys = {
      { "s", function() require("flash").jump() end, mode = { "n", "x", "o" }, desc = "Flash" },
      { "S", function() require("flash").treesitter() end, mode = { "n", "x", "o" }, desc = "Flash Treesitter" },
    },
  },

  -- Project-wide find-and-replace UI.
  {
    "nvim-pack/nvim-spectre",
    cmd = "Spectre",
    keys = {
      { "<leader>sR", function() require("spectre").open() end, desc = "Spectre: project find/replace" },
      { "<leader>sw", function() require("spectre").open_visual({ select_word = true }) end, desc = "Spectre: search word" },
    },
    opts = {},
  },

  -- Bookmarks / quick file jump.
  {
    "cbochs/grapple.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Grapple",
    keys = {
      { "<D-2>",      function() require("grapple").toggle_tags() end, desc = "Bookmarks (Cmd-2)" },
      { "<leader>fm", function() require("grapple").toggle() end,      desc = "Toggle bookmark" },
      { "<leader>fM", function() require("grapple").toggle_tags() end, desc = "List bookmarks" },
      { "<leader>1",  function() require("grapple").select({ index = 1 }) end },
      { "<leader>2",  function() require("grapple").select({ index = 2 }) end },
      { "<leader>3",  function() require("grapple").select({ index = 3 }) end },
      { "<leader>4",  function() require("grapple").select({ index = 4 }) end },
    },
    opts = { scope = "git_branch" },
  },

  -- Definition / implementation peek in floating window.
  {
    "rmagatti/goto-preview",
    event = "BufReadPost",
    opts = {
      width = 100,
      height = 20,
      border = "rounded",
      default_mappings = false,
      focus_on_open = true,
    },
    keys = {
      { "<leader>cd", function() require("goto-preview").goto_preview_definition() end,     desc = "Peek definition" },
      { "<leader>ci", function() require("goto-preview").goto_preview_implementation() end, desc = "Peek implementation" },
      { "<leader>cD", function() require("goto-preview").close_all_win() end,              desc = "Close peek windows" },
    },
  },

  -- Zen / focus mode.
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    keys = {
      { "<leader>uz", "<cmd>ZenMode<cr>", desc = "Toggle Zen Mode" },
    },
    opts = {
      window = { backdrop = 0.95, width = 0.85 },
      plugins = {
        gitsigns = { enabled = true },
        tmux = { enabled = false },
      },
    },
  },

  -- Smart split navigation/resize.
  {
    "mrjones2014/smart-splits.nvim",
    event = "VeryLazy",
    keys = {
      { "<C-h>", function() require("smart-splits").move_cursor_left() end },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end },
      { "<C-k>", function() require("smart-splits").move_cursor_up() end },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end },
      { "<A-h>", function() require("smart-splits").resize_left() end },
      { "<A-j>", function() require("smart-splits").resize_down() end },
      { "<A-k>", function() require("smart-splits").resize_up() end },
      { "<A-l>", function() require("smart-splits").resize_right() end },
    },
  },

  -- Multi-cursor.
  {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "BufReadPost",
    init = function()
      vim.g.VM_default_mappings = 0
      vim.g.VM_maps = {
        ["Find Under"]         = "<C-g>",
        ["Find Subword Under"] = "<C-g>",
        ["Select All"]         = "<D-C-g>",
        ["Add Cursor Down"]    = "<A-S-Down>",
        ["Add Cursor Up"]      = "<A-S-Up>",
      }
    end,
  },
}
