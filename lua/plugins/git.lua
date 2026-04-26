return {
  -- Magit-style commit/log/branch UI.
  {
    "NeogitOrg/neogit",
    dependencies = { "nvim-lua/plenary.nvim", "sindrets/diffview.nvim" },
    cmd = { "Neogit" },
    opts = {
      kind = "tab",
      integrations = { diffview = true },
      commit_editor = { kind = "split" },
    },
  },

  -- IDE-style diff & merge view.
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd",  "<cmd>DiffviewOpen<CR>",          desc = "Diff: open" },
      { "<leader>gh",  "<cmd>DiffviewFileHistory<CR>",   desc = "Diff: file history" },
      { "<leader>gH",  "<cmd>DiffviewFileHistory %<CR>", desc = "Diff: this file's history" },
      { "<leader>gC",  "<cmd>DiffviewClose<CR>",         desc = "Diff: close" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = { merge_tool = { layout = "diff3_mixed" } },
    },
  },

  -- GitHub PR / Issue review.
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>gpl", "<cmd>Octo pr list<CR>",      desc = "Octo: PR list" },
      { "<leader>gpc", "<cmd>Octo pr create<CR>",    desc = "Octo: PR create" },
      { "<leader>gpr", "<cmd>Octo review start<CR>", desc = "Octo: start review" },
      { "<leader>gil", "<cmd>Octo issue list<CR>",   desc = "Octo: issue list" },
    },
    opts = {
      enable_builtin = true,
      default_to_projects_v2 = false,
      suppress_missing_scope = { projects_v2 = true },
    },
  },

  -- Conflict marker UI.
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    event = "BufReadPost",
    opts = {
      default_mappings = true,
      default_commands = true,
      disable_diagnostics = false,
      list_opener = "copen",
      highlights = { incoming = "DiffAdd", current = "DiffText" },
    },
  },

  -- Open file in browser (GitHub/GitLab).
  {
    "ruifm/gitlinker.nvim",
    keys = {
      { "<leader>gy", function() require("gitlinker").get_buf_range_url("n") end, desc = "Git: copy permalink" },
      { "<leader>gy", function() require("gitlinker").get_buf_range_url("v") end, mode = "v", desc = "Git: copy permalink (range)" },
    },
    opts = { mappings = nil },
  },

  -- Lazygit float.
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter" },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<CR>", desc = "LazyGit" },
    },
  },
}
