return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
      "leoluz/nvim-dap-go",
      "mfussenegger/nvim-dap-python",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup({
        controls = { enabled = true, element = "repl" },
        layouts = {
          {
            elements = {
              { id = "scopes",      size = 0.4 },
              { id = "breakpoints", size = 0.2 },
              { id = "stacks",      size = 0.2 },
              { id = "watches",     size = 0.2 },
            },
            position = "left",
            size = 40,
          },
          {
            elements = {
              { id = "repl",    size = 0.5 },
              { id = "console", size = 0.5 },
            },
            position = "bottom",
            size = 12,
          },
        },
        floating = { border = "rounded" },
      })

      require("nvim-dap-virtual-text").setup({
        commented = true,
        virt_text_pos = "eol",
      })

      -- Auto-toggle UI when sessions start/end.
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- Per-language adapters.
      require("dap-go").setup()
      require("dap-python").setup(vim.fn.expand("~/.local/share/nvim/mason/packages/debugpy/venv/bin/python"))

      -- Diagnostic-style breakpoint signs (IDEA red dot vibe).
      vim.fn.sign_define("DapBreakpoint",         { text = "●", texthl = "DiagnosticError",  linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition",{ text = "◆", texthl = "DiagnosticWarn",   linehl = "", numhl = "" })
      vim.fn.sign_define("DapLogPoint",           { text = "◆", texthl = "DiagnosticInfo",   linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped",            { text = "▶", texthl = "DiagnosticOk",     linehl = "Visual", numhl = "" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "●", texthl = "DiagnosticHint",   linehl = "", numhl = "" })
    end,
  },
}
