-- Custom snacks.dashboard.
--
-- Single-column centered layout. Sections separated by thin rules. NHYC ASCII art
-- header (rows 3-4 use explicit per-line strings so trailing spaces in the C glyph
-- survive editor / formatter passes).
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        width = 56,
        preset = {
          header = table.concat({
            "",
            "███╗   ██╗██╗  ██╗██╗   ██╗ ██████╗",
            "████╗  ██║██║  ██║╚██╗ ██╔╝██╔════╝",
            "██╔██╗ ██║███████║ ╚████╔╝ ██║     ",
            "██║╚██╗██║██╔══██║  ╚██╔╝  ██║     ",
            "██║ ╚████║██║  ██║   ██║   ╚██████╗",
            "╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝",
            "",
            "      H A P P Y   C O D I N G",
            "",
          }, "\n"),
          keys = {
            { icon = " ", key = "f", desc = "Find File",       action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "n", desc = "New File",        action = ":ene | startinsert" },
            { icon = " ", key = "g", desc = "Find Text",       action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files",    action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = " ", key = "p", desc = "Projects",        action = ":lua Snacks.picker.projects()" },
            { icon = " ", key = "c", desc = "Config",          action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })" },
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = " ", key = "z", desc = "Zen Mode",        action = ":ZenMode" },
            { icon = "󰒲 ", key = "l", desc = "Lazy",            action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit",            action = ":qa" },
          },
        },
        sections = {
          { section = "header", padding = 1 },
          { text = { { "──────────────────────────────────────────", hl = "SnacksDashboardDir" } }, align = "center", padding = 1 },
          { section = "keys", gap = 1, padding = 1 },
          { text = { { "──────────────────────────────────────────", hl = "SnacksDashboardDir" } }, align = "center", padding = 1 },
          { pane = 1, section = "recent_files", title = "Recent Files", icon = " ", limit = 5, padding = 1, indent = 2 },
          { section = "startup", align = "center" },
        },
        formats = {
          key = function(item)
            return { { "[", hl = "SnacksDashboardDesc" }, { item.key, hl = "SnacksDashboardKey" }, { "]", hl = "SnacksDashboardDesc" } }
          end,
        },
      },
    },
  },
}
