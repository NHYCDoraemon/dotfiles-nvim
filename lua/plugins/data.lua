return {
  -- Database UI.
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_save_location  = vim.fn.stdpath("data") .. "/db_ui"
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_force_echo_notifications = 1
      vim.g.db_ui_win_position = "left"
    end,
  },

  -- HTTP client for .http files.
  {
    "mistweaverco/kulala.nvim",
    ft = { "http", "rest" },
    keys = {
      { "<leader>Rs", function() require("kulala").run() end,         desc = "HTTP: send request" },
      { "<leader>Rt", function() require("kulala").toggle_view() end, desc = "HTTP: toggle response view" },
      { "<leader>Rp", function() require("kulala").jump_prev() end,   desc = "HTTP: prev request" },
      { "<leader>Rn", function() require("kulala").jump_next() end,   desc = "HTTP: next request" },
      { "<leader>Ri", function() require("kulala").inspect() end,     desc = "HTTP: inspect" },
    },
    opts = {
      default_view = "body",
      default_env  = "dev",
      debug = false,
      contenttypes = {
        ["application/json"] = { ft = "json", formatter = { "jq", "." } },
      },
    },
  },
}
