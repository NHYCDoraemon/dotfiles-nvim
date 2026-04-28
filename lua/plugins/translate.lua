-- Translate via pantran.nvim — modern lua-native, popup-based, multi-engine.
-- Default engine is Google (no API key, online via curl). The popup is
-- interactive: edit the translation if you want, press <CR> to replace the
-- source, <Esc> to dismiss without replace.
--
-- Keymaps:
--   <leader>ct  (n) operator: translates the next motion (e.g. <leader>ctip = translate inner paragraph)
--   <leader>ct  (v) translate the current visual selection
--   <leader>cT      open Pantran's interactive prompt (pick engine / source / target)
return {
  {
    "potamides/pantran.nvim",
    cmd = "Pantran",
    keys = {
      { "<leader>ct", function() return require("pantran").motion_translate() end,
        expr = true, mode = "n", desc = "Translate (motion)" },
      { "<leader>ct", ":Pantran<CR>",
        mode = "x", silent = true, desc = "Translate (selection)" },
      { "<leader>cT", "<cmd>Pantran<CR>",
        desc = "Translate (interactive prompt)" },
    },
    opts = {
      default_engine = "google",
      engines = {
        google = {
          default_source = "auto",
          default_target = "zh-CN",   -- 默认翻译到中文（最常见诉求是英文→中文）
        },
      },
      window = {
        window_config = {
          border = "rounded",
        },
      },
    },
  },
}
