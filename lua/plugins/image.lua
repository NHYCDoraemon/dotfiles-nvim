-- Image / diagram rendering.
--
-- Strategy by environment:
--   * Neovide (GUI):      image.nvim + diagram.nvim → real inline pixel render.
--   * Ghostty (terminal): both disabled → no fake popup. <leader>mp browser
--     preview / Preview.app on .mmd / .puml are the working alternatives.
--
-- The Neovide check happens via lazy.nvim's `enabled = function()` predicate
-- which is evaluated at spec resolution time.
return {
  -- Always disable Snacks.image — produces kitty-protocol noise notifications
  -- and conflicts with image.nvim when both try to render.
  {
    "folke/snacks.nvim",
    opts = { image = { enabled = false } },
  },

  -- image.nvim. Installed unconditionally. We CAN'T gate by `vim.g.neovide` at
  -- spec eval time — Neovide sets that variable AFTER lazy.nvim resolves specs,
  -- so `enabled = function() return vim.g.neovide ~= nil end` always evaluated
  -- to false and image.nvim never installed.
  {
    "3rd/image.nvim",
    build = false,
    event = "VeryLazy",
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          floating_windows = false,
          filetypes = { "markdown", "vimwiki", "Avante" },
        },
        neorg = { enabled = false },
        typst = { enabled = false },
        html  = { enabled = false },
        css   = { enabled = false },
      },
      max_width                       = 100,
      max_height                      = 30,
      max_height_window_percentage    = 60,
      window_overlap_clear_enabled    = true,
      window_overlap_clear_ft_ignore  = { "cmp_menu", "cmp_docs", "snacks_picker_list", "" },
      editor_only_render_when_focused = false,
      hijack_file_patterns            = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
    },
  },

  -- diagram.nvim — also unconditional (same vim.g.neovide timing issue).
  {
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
    ft = { "markdown", "mermaid" },
    opts = function()
      return {
        events = {
          render_buffer = { "InsertLeave", "BufWinEnter", "TextChanged" },
          clear_buffer  = { "BufLeave" },
        },
        renderer_options = {
          mermaid = {
            background_color = "transparent",
            theme = "dark",
            scale = 2,
          },
          plantuml = { charset = "utf-8" },
          d2       = { theme_id = 1, dark_theme_id = 200 },
        },
        integrations = {
          require("diagram.integrations.markdown"),
        },
      }
    end,
  },
}
