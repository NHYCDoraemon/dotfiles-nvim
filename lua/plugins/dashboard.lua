-- Centered, breathing-room dashboard. Rose-pine-tuned aesthetic.
-- All sections center-aligned; heading separators use thin rules.
-- C-glyph trailing spaces preserved via per-line table.
return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      local date = os.date("%A · %d %B")  -- e.g. "Sunday · 27 April"

      opts.dashboard = vim.tbl_deep_extend("force", opts.dashboard or {}, {
        width = 60,
        preset = {
          header = table.concat({
            "",
            "███╗   ██╗██╗  ██╗██╗   ██╗ ██████╗",
            "████╗  ██║██║  ██║╚██╗ ██╔╝██╔════╝",
            "██╔██╗ ██║███████║ ╚████╔╝ ██║     ",
            "██║╚██╗██║██╔══██║  ╚██╔╝  ██║     ",
            "██║ ╚████║██║  ██║   ██║   ╚██████╗",
            "╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝",
          }, "\n"),
          keys = {
            { key = "f", desc = "Find File",       action = ":lua Snacks.dashboard.pick('files')" },
            { key = "n", desc = "New File",        action = ":ene | startinsert" },
            { key = "g", desc = "Find Text",       action = ":lua Snacks.dashboard.pick('live_grep')" },
            { key = "r", desc = "Recent Files",    action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { key = "p", desc = "Projects",        action = ":lua Snacks.picker.projects({ dev = { '~/ideaProjects', '~/GolandProjects', '~/projects' } })" },
            { key = "c", desc = "Configuration",   action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })" },
            { key = "s", desc = "Restore Session", section = "session" },
            { key = "z", desc = "Zen Mode",        action = ":ZenMode" },
            { key = "l", desc = "Lazy",            action = ":Lazy" },
            { key = "q", desc = "Quit",            action = ":qa" },
          },
        },
        formats = {
          -- Render each key row as: " [ f ]   Find File "
          key  = function(item) return { { "[ " .. item.key .. " ]", hl = "SnacksDashboardSpecial" } } end,
          icon = function() return { { "" } } end,
          desc = function(item) return { { item.desc, hl = "SnacksDashboardDesc" } } end,
        },
        sections = {
          { section = "header", padding = 1, align = "center" },

          -- Subtitle: date + greeting, framed by thin rules.
          {
            text = {
              { "─── ", hl = "SnacksDashboardDir" },
              { date, hl = "SnacksDashboardTitle" },
              { " · Happy Coding ───", hl = "SnacksDashboardDir" },
            },
            align = "center",
            padding = 2,
          },

          -- Action keys (center column).
          { section = "keys", gap = 0, padding = 1, align = "center" },

          -- Padding before recent files.
          { padding = 2 },

          -- Recent files.
          {
            text = { { "Recent", hl = "SnacksDashboardTitle" } },
            align = "center",
            padding = 1,
          },
          { section = "recent_files", limit = 4, padding = 1, indent = 0, align = "center" },

          { padding = 2 },

          -- Footer: plugin count + load time.
          { section = "startup", align = "center" },
        },
      })
      return opts
    end,
  },
}
