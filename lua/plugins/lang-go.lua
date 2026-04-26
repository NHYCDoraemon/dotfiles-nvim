return {
  {
    "olexsmir/gopher.nvim",
    ft = "go",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    build = function()
      vim.cmd([[silent! GoInstallDeps]])
    end,
    opts = {
      commands = {
        go = "go",
        gomodifytags = "gomodifytags",
        gotests = "gotests",
        impl = "impl",
        iferr = "iferr",
      },
    },
    keys = {
      { "<leader>cgi", "<cmd>GoIfErr<cr>",     desc = "Go: insert if-err block",    ft = "go" },
      { "<leader>cgs", "<cmd>GoTagAdd json<cr>", desc = "Go: add struct json tags",   ft = "go" },
      { "<leader>cgt", "<cmd>GoTestAdd<cr>",   desc = "Go: generate test for func", ft = "go" },
    },
  },
}
