-- Curated theme pack for browsing.
--
-- All themes lazy-load on demand (only the active one consumes RAM/highlights).
-- Use `<leader>uC` to open the colorscheme picker — Snacks shows a LIVE PREVIEW
-- as you scroll the list, no commit cost, just press <Esc> to keep current.
--
-- The active default is still `catppuccin-mocha`; this just adds candidates.
return {
  -- Cool / blue family — clean, modern, popular.
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = {
      style = "moon",      -- night | storm | moon | day(light)
      transparent = false,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
      },
    },
  },

  -- Minimal / soft — warm pastel, has Dawn (light) variant.
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    opts = {
      variant = "auto",     -- main (dark) / moon (medium) / dawn (light)
      dark_variant = "main",
      styles = {
        bold = false,
        italic = true,
        transparency = false,
      },
    },
  },

  -- Warm retro — vintage feel, very gentle on eyes for long sessions.
  {
    "sainnhe/gruvbox-material",
    lazy = true,
    init = function()
      vim.g.gruvbox_material_background = "medium"     -- soft / medium / hard
      vim.g.gruvbox_material_foreground = "material"   -- material / mix / original
      vim.g.gruvbox_material_better_performance = 1
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_disable_italic_comment = 0
    end,
  },

  -- Calm green — evergreen-forest aesthetic, lowest eye strain in this set.
  {
    "sainnhe/everforest",
    lazy = true,
    init = function()
      vim.g.everforest_background = "medium"           -- soft / medium / hard
      vim.g.everforest_better_performance = 1
      vim.g.everforest_enable_italic = 1
    end,
  },

  -- IDE-clean light — closest match to IntelliJ Light & VS Code Light Modern.
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    lazy = true,
    opts = {
      options = {
        styles = {
          comments = "italic",
          keywords = "italic",
          types = "NONE",
          functions = "NONE",
        },
      },
    },
  },

  -- Bonus: high-contrast modern (popular in 2025).
  {
    "EdenEast/nightfox.nvim",
    lazy = true,
    opts = {
      options = {
        transparent = false,
        styles = {
          comments = "italic",
          keywords = "italic",
        },
      },
    },
  },
}
