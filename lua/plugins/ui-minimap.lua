return {
  {
    "Isrothy/neominimap.nvim",
    version = "v3.*.*",
    enabled = true,
    lazy = false,
    keys = {
      { "<leader>um", "<cmd>Neominimap toggle<cr>",     desc = "Minimap: toggle (global)" },
      { "<leader>uM", "<cmd>Neominimap bufToggle<cr>",  desc = "Minimap: toggle (this buffer only)" },
      { "<leader>uw", "<cmd>Neominimap winToggle<cr>",  desc = "Minimap: toggle (this window only)" },
    },
    init = function()
      -- NOTE: do NOT set global vim.opt.wrap/sidescrolloff here. This used to
      -- force wrap=false + sidescrolloff=36 on EVERY window (not just the
      -- minimap's), silently overriding options.lua's wrap=true "smart
      -- soft-wrap" design — with wrap off, long lines require horizontal
      -- scroll, so moving the cursor up/down between short and long lines
      -- yanked the viewport left/right ("screen shakes"). neominimap already
      -- sets wrap=false on its OWN window internally (window/util.lua), so
      -- this global override was pure redundancy with a real side effect.

      vim.g.neominimap = {
        auto_enable = false,  -- start disabled; toggle on demand with <leader>um
        layout = "split",
        split = {
          direction = "right",
          width = 14,
          close_if_last_window = true,
        },
        click = { enabled = true, swap_buffer_with_click = false },
        diagnostic = {
          enabled = true,
          severity = vim.diagnostic.severity.WARN,
          mode = "icon",
        },
        git = { enabled = true, mode = "sign" },
        search = { enabled = true, mode = "icon" },
        mark = { enabled = false },
        treesitter = { enabled = true },
        winopt = function(opt)
          opt.winhl = "Normal:NeominimapBackground,FloatBorder:NeominimapBorder"
          opt.signcolumn = "no"
          opt.foldcolumn = "0"
        end,
        x_multiplier = 4,
        y_multiplier = 1,
        exclude_filetypes = { "help", "neo-tree", "snacks_layout_box", "Outline", "dapui_scopes", "dapui_breakpoints", "dapui_stacks", "dapui_watches", "Avante", "AvanteInput" },
        exclude_buftypes = { "nofile", "nowrite", "quickfix", "terminal", "prompt" },
      }
    end,
  },
}
