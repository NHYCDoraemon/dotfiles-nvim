-- Prettier icon system: recolor file-type icons to match the ACTIVE theme's
-- palette instead of devicons' fixed brand colors. The palette is sampled from
-- the colorscheme's own highlight groups, so icons warm up under rose-pine by
-- day and cool down under catppuccin by night — recomputed on every ColorScheme.
--
-- (The icon glyphs themselves come from your Nerd Font — Liga Comic Mono; this
-- only changes their colors, which is the biggest "nicer icons" lever.)
return {
  {
    "rachartier/tiny-devicons-auto-colors.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      local function theme_palette()
        local groups = {
          "Function", "String", "Constant", "Identifier", "Statement",
          "Type", "Special", "Keyword", "Number", "Boolean", "Character",
          "PreProc", "Comment", "Title", "Operator",
        }
        local colors = {}
        for _, g in ipairs(groups) do
          local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = g, link = false })
          if ok and h and h.fg then
            colors[#colors + 1] = string.format("#%06x", h.fg)
          end
        end
        return colors
      end

      local function apply()
        local pal = theme_palette()
        if #pal > 0 then
          require("tiny-devicons-auto-colors").setup({ colors = pal })
        end
      end

      apply()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("tiny_devicons_recolor", { clear = true }),
        callback = vim.schedule_wrap(apply),
      })
    end,
  },
}
