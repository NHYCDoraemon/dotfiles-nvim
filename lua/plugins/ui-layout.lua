return {
  {
    "folke/edgy.nvim",
    event = "VeryLazy",
    init = function()
      vim.opt.laststatus = 3
      vim.opt.splitkeep = "screen"
    end,
    opts = {
      animate = {
        enabled = true,
        fps = 100,
        cps = 120,
      },
      wo = {
        winbar = true,
        winfixwidth = true,
        winfixheight = false,
        winhighlight = "WinBar:EdgyWinBar,Normal:EdgyNormal",
      },
      keys = {
        ["q"] = function(win) win:close() end,
        ["<c-w>>"] = function(win) win:resize("width", 2) end,
        ["<c-w><lt>"] = function(win) win:resize("width", -2) end,
        ["<c-w>+"] = function(win) win:resize("height", 2) end,
        ["<c-w>-"] = function(win) win:resize("height", -2) end,
        ["<c-w>="] = function(win) win.view.edgebar:equalize() end,
      },
      bottom = {
        { ft = "toggleterm",      size = { height = 0.3 } },
        { ft = "trouble",         size = { height = 0.3 } },
        { ft = "qf",              title = "QuickFix",       size = { height = 0.3 } },
        { ft = "OverseerList",    title = "Run / Tasks",    size = { height = 0.3 } },
        { ft = "dap-repl",        title = "Debug REPL",     size = { height = 0.3 } },
        { ft = "dapui_console",   title = "Debug Console",  size = { height = 0.3 } },
        { ft = "neotest-output",  title = "Tests Output",   size = { height = 0.3 } },
        { ft = "noice",           size = { height = 0.3 }, filter = function(buf, win) return vim.api.nvim_win_get_config(win).relative == "" end },
      },
      left = {
        { title = "Explorer",  ft = "snacks_layout_box" },
        -- DO NOT dock snacks_picker_list here — it breaks the floating picker layout
        -- by stealing the list pane and showing it as a side panel that looks like
        -- quickfix. Snacks.picker manages its own floating window stack.
        { ft = "dapui_scopes",      title = "Scopes",      size = { height = 0.25 } },
        { ft = "dapui_breakpoints", title = "Breakpoints", size = { height = 0.25 } },
        { ft = "dapui_stacks",      title = "Call Stack",  size = { height = 0.25 } },
        { ft = "dapui_watches",     title = "Watches",     size = { height = 0.25 } },
      },
      right = {
        -- Structure (Outline) docks here, IDEA-style on the right.
        { title = "Structure", ft = "Outline", pinned = true, open = "Outline", size = { width = 40 } },
        { title = "Avante",    ft = "Avante",  size = { width = 0.35 } },
        { title = "Help",      ft = "help",    size = { width = 80 } },
      },
      options = {
        left   = { size = 40 },
        bottom = { size = 12 },
        right  = { size = 50 },
        top    = { size = 10 },
      },
    },
  },
}
