return {
  {
    "olexsmir/gopher.nvim",
    ft = "go",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    build = function()
      vim.cmd([[silent! GoInstallDeps]])
    end,
    opts = {
      commands = {
        go = "go",
        gomodifytags = "gomodifytags",
        gotests = "gotests",
        impl = "impl",
        iferr = "iferr",
      },
    },
    keys = {
      { "<leader>cgi", "<cmd>GoIfErr<cr>",        desc = "Go: insert if-err block",      ft = "go" },
      { "<leader>cgs", "<cmd>GoTagAdd json<cr>",  desc = "Go: add struct json tags",     ft = "go" },
      { "<leader>cgt", "<cmd>GoTestAdd<cr>",      desc = "Go: generate test for func",   ft = "go" },
    },
  },

  -- Auto-fix on save: run gopls' source.fixAll (covers most auto-fixable
  -- staticcheck warnings, unused vars, simplifiable expressions, etc.) and
  -- source.organizeImports. Then conform.nvim runs gofumpt afterwards.
  --
  -- Manual one-shot: <leader>cF — fix everything auto-fixable in current buffer.
  {
    "neovim/nvim-lspconfig",
    init = function()
      local function go_fix_all(bufnr)
        bufnr = bufnr or vim.api.nvim_get_current_buf()
        local actions = { "source.fixAll", "source.organizeImports" }
        for _, action in ipairs(actions) do
          local params = vim.lsp.util.make_range_params(0, "utf-8")
          params.context = { only = { action }, diagnostics = {} }
          local results = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 1000)
          for _, res in pairs(results or {}) do
            for _, r in ipairs(res.result or {}) do
              if r.edit then
                vim.lsp.util.apply_workspace_edit(r.edit, "utf-8")
              elseif type(r.command) == "table" then
                vim.lsp.buf.execute_command(r.command)
              end
            end
          end
        end
      end

      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.go",
        group = vim.api.nvim_create_augroup("UserGoFixOnSave", { clear = true }),
        callback = function(args) go_fix_all(args.buf) end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "go",
        group = vim.api.nvim_create_augroup("UserGoFixKeymap", { clear = true }),
        callback = function(args)
          vim.keymap.set("n", "<leader>cF", function() go_fix_all(args.buf) end, {
            buffer = args.buf,
            desc = "Go: fix all + organize imports",
          })
        end,
      })
    end,
  },
}
