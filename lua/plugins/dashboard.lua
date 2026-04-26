-- Notion-style snacks.dashboard.
--
-- Left-aligned, generous breathing room, thin horizontal rules between blocks.
-- No boxes/borders. Section headings act as Notion "block titles". Subtle bullets
-- (`›` for keys, `·` for files) instead of icons that demand a Nerd Font.
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        width = 64,
        preset = {
          -- NHYC ASCII (rows 3 & 4 use explicit per-line strings so trailing
          -- spaces in the C glyph survive editor / formatter passes).
          header = table.concat({
            "",
            "  ███╗   ██╗██╗  ██╗██╗   ██╗ ██████╗ ",
            "  ████╗  ██║██║  ██║╚██╗ ██╔╝██╔════╝ ",
            "  ██╔██╗ ██║███████║ ╚████╔╝ ██║      ",
            "  ██║╚██╗██║██╔══██║  ╚██╔╝  ██║      ",
            "  ██║ ╚████║██║  ██║   ██║   ╚██████╗ ",
            "  ╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ",
          }, "\n"),
          keys = {
            { icon = "›", key = "f", desc = "Find File",         action = ":lua Snacks.dashboard.pick('files')" },
            { icon = "›", key = "n", desc = "New File",          action = ":ene | startinsert" },
            { icon = "›", key = "g", desc = "Find Text in Files",action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = "›", key = "r", desc = "Recent Files",      action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = "›", key = "p", desc = "Projects",          action = ":lua Snacks.picker.projects()" },
            { icon = "›", key = "c", desc = "Configuration",     action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })" },
            { icon = "›", key = "s", desc = "Restore Session",   section = "session" },
            { icon = "›", key = "z", desc = "Zen Mode",          action = ":ZenMode" },
            { icon = "›", key = "l", desc = "Lazy",              action = ":Lazy" },
            { icon = "›", key = "q", desc = "Quit",              action = ":qa" },
          },
        },
        formats = {
          -- "› f    Find File" — Notion-style left-aligned row.
          key = function(item)
            return { { item.key, hl = "SnacksDashboardSpecial" } }
          end,
          icon = function(item)
            return { { item.icon, hl = "SnacksDashboardDir" } }
          end,
          desc = function(item)
            return { { item.desc, hl = "SnacksDashboardDesc" } }
          end,
        },
        sections = {
          -- Page title (NHYC ASCII).
          { section = "header", padding = 1 },

          -- Subtitle: today's date in muted gray, Notion-like "page metadata".
          {
            text = {
              { "  Happy Coding", hl = "SnacksDashboardTitle" },
              { "  ·  ", hl = "SnacksDashboardDir" },
              { os.date("%A, %B %d"), hl = "SnacksDashboardDir" },
            },
            padding = 2,
          },

          -- Thin rule.
          { text = { { "  ─────────────────────────────────────────────────────", hl = "SnacksDashboardDir" } }, padding = 1 },

          -- "Quick Actions" block.
          { text = { { "  Quick Actions", hl = "SnacksDashboardTitle" } }, padding = 1 },
          { section = "keys", gap = 0, padding = 2, indent = 2 },

          -- Thin rule.
          { text = { { "  ─────────────────────────────────────────────────────", hl = "SnacksDashboardDir" } }, padding = 1 },

          -- "Recent" block — file list, dot bullets, dim path.
          { text = { { "  Recent", hl = "SnacksDashboardTitle" } }, padding = 1 },
          { section = "recent_files", limit = 5, padding = 2, indent = 4 },

          -- Thin rule.
          { text = { { "  ─────────────────────────────────────────────────────", hl = "SnacksDashboardDir" } }, padding = 1 },

          -- Footer: muted startup info.
          { section = "startup", padding = 1, indent = 2 },
        },
      },
    },
  },
}
