return {
  -- Catppuccin (default)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = false,
      term_colors = true,
      no_italic = false,
      no_bold = false,
      styles = {
        -- Match IDEA / GoLand: italic on "soft" tokens (comments, keywords),
        -- regular weight on types/functions/properties. Bold in mid-density
        -- code looks noisy and unlike IDE defaults.
        comments     = { "italic" },
        conditionals = { "italic" },
        keywords     = { "italic" },
        types        = {},
        functions    = {},
        properties   = {},
        booleans     = { "italic" },
        operators    = {},
        loops        = { "italic" },
      },
      integrations = {
        blink_cmp = true,
        dropbar = { enabled = true, color_mode = true },
        flash = true,
        gitsigns = true,
        mason = true,
        neogit = true,
        noice = true,
        notify = true,
        rainbow_delimiters = true,
        snacks = { enabled = true },
        telescope = { enabled = true },
        treesitter = true,
        treesitter_context = true,
        which_key = true,
        indent_blankline = { enabled = true, scope_color = "lavender" },
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors      = { "italic" },
            hints       = { "italic" },
            warnings    = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors      = { "underline" },
            hints       = { "underline" },
            warnings    = { "underline" },
            information = { "underline" },
          },
        },
      },
    },
  },

  -- Kanagawa (alternate)
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 999,
    opts = {
      compile = false,
      undercurl = true,
      transparent = false,
      dimInactive = false,
      terminalColors = true,
      -- Match IDEA: italic on keywords/comments, no bold anywhere by default.
      commentStyle  = { italic = true },
      keywordStyle  = { italic = true },
      statementStyle= {},
      typeStyle     = {},
      functionStyle = {},
      theme = "wave",
      background = { dark = "wave", light = "lotus" },
    },
  },

  -- Default colorscheme at LazyVim level.
  -- dawnfox = nightfox 系列的暖色 light 变体，纸感+柔光，文艺向。
  -- 切到其他主题用 <leader>uC（picker）；rose-pine main/dawn 切换用 <leader>uL。
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "dawnfox",
    },
  },
}
