-- snacks.indent — minimalist single-color indent guides.
--
-- Replaces mini.indentscope (which only drew the current scope, leaving
-- outer levels static and the editor feeling rigid). snacks.indent draws
-- thin guides at every indent level + an animated chunk outline that
-- "scans" through the current scope, using a single muted highlight (no
-- rainbow, no theatrics — 禁欲风).
return {
  {
    "folke/snacks.nvim",
    opts = {
      indent = {
        enabled = true,
        char = "▏",                 -- thin left-edge bar (less heavy than │)
        only_scope = false,         -- show guides at every level, not just current
        only_current = false,
        hl = "SnacksIndent",        -- single muted color (theme-driven)

        -- Animated "scope scan": when you enter a function/block the chunk
        -- outline draws itself top-to-bottom over ~500ms. Subtle but alive.
        scope = {
          enabled = true,
          char = "▏",
          underline = false,
          only_current = false,
          hl = "SnacksIndentScope", -- the active scope guide (subtly stronger color)
        },

        -- Chunk outline draws a bracket around the current code block.
        -- Disabled — too visually heavy for the minimalist target.
        chunk = {
          enabled = false,
        },

        animate = {
          enabled = true,
          style = "out",            -- top-to-bottom scan
          easing = "linear",
          duration = {
            step = 20,               -- ms per row
            total = 500,             -- cap total animation
          },
        },
      },
    },
  },
}
