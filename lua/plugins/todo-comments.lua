-- todo-comments.nvim — extended keyword set (workflow + Chinese aliases).
--
-- Adds:
--   * WIP / 进行中
--   * REVIEW / 审查
--   * DEPRECATED / 已废弃
--   * Chinese equivalents for the standard set: 待办 修复 优化 注意
--   * Pattern supports both ASCII `:` and Chinese full-width `：`
-- Scope <leader>st / <leader>sT to the current project's git root instead of
-- nvim's cwd. Default behavior searches getcwd() which is often the home
-- directory or some unrelated path → user sees TODOs from LazyVim source,
-- other projects, or worse.
local function project_root()
  local file = vim.api.nvim_buf_get_name(0)
  local start = (file ~= "") and vim.fn.fnamemodify(file, ":p:h") or vim.fn.getcwd()
  local found = vim.fs.find(
    { ".git", "go.mod", "package.json", "Cargo.toml", "pom.xml", "build.gradle", "pyproject.toml" },
    { upward = true, path = start }
  )
  if #found > 0 then return vim.fn.fnamemodify(found[1], ":h") end
  return vim.fn.getcwd()
end

return {
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    keys = {
      -- Override LazyVim's default <leader>st — scope to current project root.
      {
        "<leader>st",
        function() Snacks.picker.todo_comments({ cwd = project_root() }) end,
        desc = "Todo (current project)",
      },
      {
        "<leader>sT",
        function() Snacks.picker.todo_comments({ cwd = project_root(), keywords = { "TODO", "FIX", "FIXME" } }) end,
        desc = "Todo/Fix/Fixme (current project)",
      },
      -- Buffer-only TODO list (loclist) — useful for "what's left in this file?"
      {
        "<leader>sl",
        function() vim.cmd("TodoLocList") end,
        desc = "Todo (current file only)",
      },
    },
    opts = {
      keywords = {
        FIX = {
          icon = " ",
          color = "error",
          alt = { "FIXME", "BUG", "FIXIT", "ISSUE", "修复" },
        },
        TODO = {
          icon = " ",
          color = "info",
          alt = { "待办", "TASK" },
        },
        HACK = {
          icon = " ",
          color = "warning",
          alt = { "黑魔法" },
        },
        WARN = {
          icon = " ",
          color = "warning",
          alt = { "WARNING", "XXX", "注意" },
        },
        PERF = {
          icon = " ",
          color = "default",
          alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE", "优化" },
        },
        NOTE = {
          icon = " ",
          color = "hint",
          alt = { "INFO", "提示" },
        },
        TEST = {
          icon = "⏲ ",
          color = "test",
          alt = { "TESTING", "PASSED", "FAILED" },
        },

        -- New custom workflow keywords:
        WIP = {
          icon = "🚧",
          color = "warning",
          alt = { "INPROGRESS", "WORKING", "进行中" },
        },
        REVIEW = {
          icon = " ",
          color = "warning",
          alt = { "PR", "审查", "待审" },
        },
        DEPRECATED = {
          icon = " ",
          color = "error",
          alt = { "DEPRECATE", "OBSOLETE", "已废弃" },
        },
      },

      -- Match both ASCII `:` and Chinese full-width `：` after the keyword.
      -- Default only handled `:` so `// TODO：xxx` (with full-width colon)
      -- went unrecognized.
      highlight = {
        multiline = true,
        keyword = "wide",
        after = "fg",
        -- Use level-1 long brackets `[=[...]=]` because the regex contains `]]`
        -- which would prematurely close `[[...]]`.
        pattern = [=[.*<(KEYWORDS)\s*[:：]]=],
      },
      search = {
        pattern = [=[\b(KEYWORDS)\s*[:：]]=],
      },
    },
  },
}
