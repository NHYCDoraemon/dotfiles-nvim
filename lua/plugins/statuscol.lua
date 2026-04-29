-- statuscol.nvim — clean, customisable status column.
-- The default vim status column squeezes signs + line numbers together with
-- inconsistent widths. statuscol gives us:
--   1. a fixed-width sign segment (no jitter as diagnostics come/go),
--   2. a line-number segment with right-aligned relative numbers,
--   3. a subtle space gutter between signs and numbers.
-- Folds are NOT shown (the user prefers folding off).
return {
  {
    "luukvbaal/statuscol.nvim",
    event = "BufReadPost",
    config = function()
      local builtin = require("statuscol.builtin")
      require("statuscol").setup({
        relculright = true,
        bt_ignore = { "terminal", "nofile" },
        ft_ignore = {
          "neo-tree", "snacks_dashboard", "snacks_layout_box",
          "lazy", "mason", "help", "Outline", "Trouble", "trouble",
          "Avante", "AvanteInput", "no-neck-pain", "noice",
        },
        segments = {
          -- Sign column — fixed width 1, only diagnostic / git etc.
          { sign = { namespace = { ".*" }, maxwidth = 1, colwidth = 1, auto = true },
            click = "v:lua.ScSa" },
          -- Tiny gap between signs and numbers (visual breathing room).
          { text = { " " } },
          -- Line numbers (relative + current absolute), right aligned.
          { text = { builtin.lnumfunc, " " },
            click = "v:lua.ScLa" },
        },
      })
    end,
  },
}
