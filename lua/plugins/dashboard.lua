-- Custom snacks.dashboard header.
-- Built from explicit per-line strings so trailing spaces in the C glyph
-- (rows 3 and 4) cannot be silently trimmed by editors / formatters.
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
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
        },
      },
    },
  },
}
