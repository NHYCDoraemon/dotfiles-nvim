-- Custom snacks.dashboard.
-- Header uses an explicit string-per-line table so trailing spaces in the C glyph
-- (rows 3 and 4 of NHYC) survive editor / formatter passes.
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        width = 60,
        row = nil,
        col = nil,
        pane_gap = 4,
        autokeys = "1234567890abcdefghilmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
        preset = {
          header = table.concat({
            "███╗   ██╗██╗  ██╗██╗   ██╗ ██████╗",
            "████╗  ██║██║  ██║╚██╗ ██╔╝██╔════╝",
            "██╔██╗ ██║███████║ ╚████╔╝ ██║     ",
            "██║╚██╗██║██╔══██║  ╚██╔╝  ██║     ",
            "██║ ╚████║██║  ██║   ██║   ╚██████╗",
            "╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝",
            "",
            "           H A P P Y    C O D I N G",
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
          { section = "header" },
          { pane = 2, icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
          { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
          { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
          {
            pane = 2,
            icon = " ",
            title = "Git Status",
            section = "terminal",
            enabled = function() return Snacks.git.get_root() ~= nil end,
            cmd = "git --no-pager diff --stat -B -M -C",
            height = 10,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          { section = "startup" },
        },
      },
    },
  },
}
