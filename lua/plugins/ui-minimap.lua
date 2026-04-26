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
      vim.opt.wrap = false
      vim.opt.sidescrolloff = 36

      vim.g.neominimap = {
        auto_enable = true,
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
