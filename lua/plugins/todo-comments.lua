-- todo-comments.nvim — extended keyword set (workflow + Chinese aliases).
--
-- Adds:
--   * WIP / 进行中
--   * REVIEW / 审查
--   * DEPRECATED / 已废弃
--   * Chinese equivalents for the standard set: 待办 修复 优化 注意
--   * Pattern supports both ASCII `:` and Chinese full-width `：`
return {
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
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
        pattern = [[.*<(KEYWORDS)\s*[:：]]],
      },
      search = {
        pattern = [[\b(KEYWORDS)\s*[:：]]],
      },
    },
  },
}
