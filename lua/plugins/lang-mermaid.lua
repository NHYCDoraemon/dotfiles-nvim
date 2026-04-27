-- Mermaid (.mmd) file support.
--
-- mermaid-cli (mmdc) renders .mmd → PNG; Snacks.image then displays the PNG
-- inline (Neovide / Ghostty 1.3+ with kitty image protocol).
--
-- Workflow:
--   1. Open  foo.mmd  → buffer opens with Mermaid syntax (treated as text + ts highlight)
--   2. <leader>mr     → render to /tmp/<basename>.png and show in a floating image
--   3. On :w          → auto-render in background; the floating preview refreshes
--
-- Same logic also targets ```mermaid``` blocks inside markdown via render-markdown.
return {
  -- Filetype + treesitter highlighting for .mmd
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.filetype.add({ extension = { mmd = "mermaid", mermaid = "mermaid" } })
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "mermaid" })
    end,
  },

  -- (Render keymap and auto-render-on-save moved to lua/config/autocmds.lua —
  --  registering inside snacks.nvim's `init` was unreliable: snacks loads on
  --  VeryLazy, sometimes after FileType=mermaid had already fired, so the
  --  buffer-local <leader>mr binding never got attached. autocmds.lua loads
  --  eagerly at startup, before any file-open events.)
}
