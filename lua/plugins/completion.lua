-- blink.cmp keymap upgrades.
-- LazyVim uses preset = "enter" (Enter accepts, Up/Down navigate, Tab does
-- snippet placeholder jump only). This adds Tab/Shift-Tab and Ctrl-J/Ctrl-K
-- for menu navigation, so you don't have to leave the home row.
return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        preset = "enter",   -- Enter accepts (LazyVim default, kept)

        -- Tab / Shift-Tab: navigate menu when visible; otherwise jump in snippet.
        ["<Tab>"] = {
          "select_next",
          "snippet_forward",
          "fallback",
        },
        ["<S-Tab>"] = {
          "select_prev",
          "snippet_backward",
          "fallback",
        },

        -- Ctrl-J / Ctrl-K: vim-style navigate menu (always, regardless of context).
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },

        -- Ctrl-Space: show menu manually.
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },

        -- Ctrl-y: super-tab-style accept (works even if Enter is used for newline).
        ["<C-y>"] = { "select_and_accept" },

        -- Esc: dismiss menu (then second Esc exits insert).
        ["<C-e>"] = { "hide", "fallback" },

        -- Ctrl-b / Ctrl-f: scroll docs popup.
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      },
      completion = {
        list = {
          selection = {
            preselect = true,    -- highlight the first item by default
            auto_insert = false, -- do NOT auto-insert as you type (only on accept)
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },
        ghost_text = {
          enabled = true,        -- show inline preview of top suggestion
        },
      },
    },
  },
}
