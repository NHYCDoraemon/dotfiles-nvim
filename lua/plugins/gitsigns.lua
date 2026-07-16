-- Inline git blame on the current line (IDE-style): a dim end-of-line note
-- showing who last touched this line, when, and the commit summary. Updates as
-- the cursor moves. gitsigns is already installed (LazyVim) — this only flips on
-- the blame feature.
return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 400,
        ignore_whitespace = false,
      },
      current_line_blame_formatter = "   <author>, <author_time:%R> · <summary>",
    },
  },
}
