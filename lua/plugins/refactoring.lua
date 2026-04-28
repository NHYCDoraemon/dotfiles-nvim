-- refactoring.nvim — IntelliJ-style refactor menu (ThePrimeagen).
--
-- Supports: Go, TypeScript, JavaScript, Python, Lua, C/C++, Java, PHP, Ruby.
-- All under the <leader>cr* namespace (matches the existing <leader>c "code"
-- group: <leader>ca code-action, <leader>cF fix-all, <leader>cd peek, etc.).
--
-- Two ways to use:
--
--   <leader>cr   (n/x)   single picker — shows every available refactor for
--                        the current position/selection. Good when you can't
--                        remember the specific shortcut.
--   <leader>cre  (x)     Extract function       (must select range first)
--   <leader>crf  (x)     Extract function to a new file
--   <leader>crv  (x)     Extract variable
--   <leader>cri  (n/x)   Inline variable
--   <leader>crb  (n)     Extract block
--   <leader>crd  (n/x)   Debug: print a "<file>:<line>" anchor at cursor
--   <leader>crp  (n/x)   Debug: print var (selection or word under cursor)
--   <leader>crc  (n)     Cleanup debug prints inserted by the above
return {
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "lewis6991/async.nvim",                 -- new requirement (oct 2024+)
      "nvim-treesitter/nvim-treesitter",     -- treesitter queries used internally
    },
    keys = {
      { "<leader>cr",  function() require("refactoring").select_refactor() end,
        mode = { "n", "x" }, desc = "Refactor: menu" },

      { "<leader>cre", function() require("refactoring").refactor("Extract Function") end,
        mode = "x", desc = "Refactor: extract function" },
      { "<leader>crf", function() require("refactoring").refactor("Extract Function To File") end,
        mode = "x", desc = "Refactor: extract function → file" },
      { "<leader>crv", function() require("refactoring").refactor("Extract Variable") end,
        mode = "x", desc = "Refactor: extract variable" },
      { "<leader>cri", function() require("refactoring").refactor("Inline Variable") end,
        mode = { "n", "x" }, desc = "Refactor: inline variable" },
      { "<leader>crb", function() require("refactoring").refactor("Extract Block") end,
        mode = "n", desc = "Refactor: extract block" },

      { "<leader>crd", function() require("refactoring").debug.printf({ below = false }) end,
        mode = "n", desc = "Debug: print anchor (above)" },
      { "<leader>crp", function() require("refactoring").debug.print_var() end,
        mode = { "n", "x" }, desc = "Debug: print var" },
      { "<leader>crc", function() require("refactoring").debug.cleanup({}) end,
        mode = "n", desc = "Debug: cleanup prints" },
    },
    opts = {
      prompt_func_return_type = {
        go        = false,
        java      = false,
        cpp       = false,
        c         = false,
        h         = false,
        hpp       = false,
        cxx       = false,
      },
      prompt_func_param_type = {
        go        = false,
        java      = false,
        cpp       = false,
        c         = false,
        h         = false,
        hpp       = false,
        cxx       = false,
      },
      printf_statements = {},
      print_var_statements = {},
      show_success_message = true,
    },
  },
}
