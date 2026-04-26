-- Disable snacks.scroll's smooth scrolling.
--
-- Smooth scroll animates topline incrementally over many frames. Each frame,
-- nvim-treesitter-context recomputes and redraws its sticky-scope header
-- (and dropbar refreshes its breadcrumb). The result was visible flicker on
-- the top chrome whenever the user pressed `j` / `k` near the viewport edge
-- (or any motion that causes a scroll given scrolloff=8).
--
-- We already disabled mini.animate.scroll for the same reason; this finishes
-- the job. Scrolling is now instantaneous — chrome stays stable.
return {
  {
    "folke/snacks.nvim",
    opts = {
      scroll = { enabled = false },
    },
  },
}
