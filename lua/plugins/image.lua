-- True in-editor image rendering — replaces Snacks.image's flaky Ghostty path.
--
-- 3rd/image.nvim:
--   * Battle-tested kitty graphics protocol implementation that works in
--     Ghostty / Kitty / WezTerm / Neovide without protocol-detection drama.
--   * Auto-renders ![](path.png) in markdown buffers as you scroll past them.
--   * Auto-renders standalone .png / .jpg / .svg files when opened.
--
-- 3rd/diagram.nvim:
--   * Watches markdown buffers for ```mermaid``` / ```d2``` / ```plantuml```
--     code blocks. Pipes each block through its CLI (mmdc / d2 / plantuml),
--     hands the resulting PNG to image.nvim, displays inline.
--   * No browser, no separate preview pane — diagrams render in place.
return {
  -- Disable Snacks.image — image.nvim takes over completely.
  {
    "folke/snacks.nvim",
    opts = { image = { enabled = false } },
  },

  -- Image renderer (Kitty graphics protocol).
  {
    "3rd/image.nvim",
    build = false,
    event = "VeryLazy",
    opts = {
      backend = "kitty",        -- Ghostty supports kitty graphics protocol
      processor = "magick_cli", -- shell out to `magick` (already installed)

      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          floating_windows = false,
          filetypes = { "markdown", "vimwiki", "Avante" },
        },
        neorg  = { enabled = false },
        typst  = { enabled = false },
        html   = { enabled = false },
        css    = { enabled = false },
      },

      max_width                          = 100,
      max_height                         = 30,
      max_width_window_percentage        = nil,
      max_height_window_percentage       = 60,
      window_overlap_clear_enabled       = true,
      window_overlap_clear_ft_ignore     = { "cmp_menu", "cmp_docs", "snacks_picker_list", "" },
      editor_only_render_when_focused    = false,
      tmux_show_only_in_active_window    = false,
      hijack_file_patterns               = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
    },
  },

  -- Mermaid / D2 / PlantUML inline rendering inside markdown — Neovide ONLY.
  --
  -- In terminal nvim (Ghostty), image.nvim's kitty-graphics path is unreliable:
  -- it pops empty floating windows instead of rendering. Disabling diagram.nvim
  -- there means mermaid blocks stay as plain code — cleaner failure mode.
  -- For terminal users, <leader>mp opens the markdown in a browser preview
  -- where mermaid.js handles rendering natively.
  {
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
    ft = { "markdown", "mermaid" },
    enabled = function() return vim.g.neovide ~= nil end,
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
          d2       = { theme_id = 1, dark_theme_id = 200, scale = nil, layout = nil, sketch = false },
        },
        integrations = {
          require("diagram.integrations.markdown"),
        },
      }
    end,
  },
}
