-- Motion hints: overlays the vim motions (w/b/e/f/^/$ …) that would move the
-- cursor to each spot on the current line/nearby lines — a gentle way to build
-- muscle memory and press fewer keys. Off by default; toggle when you want it.
--   <leader>uP → toggle precognition hints
return {
  {
    "tris203/precognition.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>uP", function() require("precognition").toggle() end, desc = "Toggle precognition hints" },
    },
    opts = {
      startVisible = false,
    },
  },
}
