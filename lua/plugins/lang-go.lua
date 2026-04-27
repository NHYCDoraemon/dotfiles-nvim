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

  -- Static analysis / visualization commands. Wraps `go-callvis` and `goda`
  -- (CLI tools — installed via go install in install.sh).
  --
  -- Workflow:
  --   1. Open any .go file
  --   2. <leader>cgv → browser opens with full function call graph from main()
  --   3. Click nodes to navigate; pan/zoom for the whole project
  --
  -- Requires: go-callvis, goda, graphviz (dot). Installed by install.sh.
  {
    "olexsmir/gopher.nvim",
    optional = true,
    keys = {
      -- Full project call graph from main(): every function, every call edge,
      -- color-coded by package. Spawns go-callvis in HTTP server mode and opens
      -- the browser when the server is ready.
      --
      -- IMPORTANT: do NOT pass `-file` together with `-http` — `-file` switches
      -- go-callvis to one-shot file mode and the HTTP server never starts.
      {
        "<leader>cgv",
        function()
          local cwd = vim.fn.getcwd()
          local args = { "go-callvis", "-nostd", "-group", "pkg,type", "-http", ":7878", "./..." }
          _G.__go_callvis_job = _G.__go_callvis_job or {}
          if _G.__go_callvis_job.pid and vim.fn.jobwait({ _G.__go_callvis_job.id }, 0)[1] == -1 then
            vim.notify("go-callvis already running — reopening browser at http://localhost:7878", vim.log.levels.INFO)
            vim.fn.system("open http://localhost:7878")
            return
          end
          _G.__go_callvis_job.id = vim.fn.jobstart(args, {
            cwd = cwd,
            on_stdout = function(_, data)
              for _, line in ipairs(data) do
                if line:match("http serving at") then
                  vim.schedule(function() vim.fn.system("open http://localhost:7878") end)
                end
              end
            end,
            on_stderr = function(_, data)
              local msg = table.concat(data, "\n"):gsub("\n+$", "")
              if msg ~= "" then vim.schedule(function() vim.notify("go-callvis: " .. msg, vim.log.levels.WARN) end) end
            end,
            on_exit = function(_, code)
              if code ~= 0 then
                vim.schedule(function() vim.notify("go-callvis exited with code " .. code, vim.log.levels.ERROR) end)
              end
              _G.__go_callvis_job.id = nil
            end,
          })
          _G.__go_callvis_job.pid = vim.fn.jobpid(_G.__go_callvis_job.id)
          vim.notify("go-callvis starting (~10-30s for first analysis)...", vim.log.levels.INFO)
        end,
        desc = "Go: visualize full call graph (browser)",
        ft = "go",
      },

      -- Focus the call graph on the package containing the current file.
      -- Useful when the full project graph is too dense.
      {
        "<leader>cgV",
        function()
          local pkg_dir = vim.fn.expand("%:p:h")
          local cwd = vim.fn.getcwd()
          local rel = pkg_dir:sub(#cwd + 2)  -- strip cwd prefix + slash
          if rel == "" then rel = "." end
          local args = { "go-callvis", "-nostd", "-focus", rel, "-http", ":7878", "./..." }
          if _G.__go_callvis_job and _G.__go_callvis_job.id and vim.fn.jobwait({ _G.__go_callvis_job.id }, 0)[1] == -1 then
            vim.fn.jobstop(_G.__go_callvis_job.id)
          end
          _G.__go_callvis_job = { id = vim.fn.jobstart(args, {
            cwd = cwd,
            on_stdout = function(_, data)
              for _, line in ipairs(data) do
                if line:match("http serving at") then
                  vim.schedule(function() vim.fn.system("open http://localhost:7878") end)
                end
              end
            end,
            on_stderr = function(_, data)
              local msg = table.concat(data, "\n"):gsub("\n+$", "")
              if msg ~= "" then vim.schedule(function() vim.notify("go-callvis: " .. msg, vim.log.levels.WARN) end) end
            end,
          }) }
          vim.notify("go-callvis (focus=" .. rel .. ") starting...", vim.log.levels.INFO)
        end,
        desc = "Go: call graph focused on current package",
        ft = "go",
      },

      -- Stop the running go-callvis HTTP server.
      {
        "<leader>cgx",
        function()
          if _G.__go_callvis_job and _G.__go_callvis_job.id then
            vim.fn.jobstop(_G.__go_callvis_job.id)
            _G.__go_callvis_job.id = nil
            vim.notify("go-callvis stopped", vim.log.levels.INFO)
          else
            vim.notify("go-callvis not running", vim.log.levels.WARN)
          end
        end,
        desc = "Go: stop go-callvis server",
        ft = "go",
      },

      -- Module-level dependency tree (lighter, text-based, in nvim buffer).
      {
        "<leader>cgg",
        function()
          vim.cmd("vsplit | term go mod graph | head -200")
        end,
        desc = "Go: module dependency graph",
        ft = "go",
      },

      -- Package-level dependency tree (goda).
      {
        "<leader>cgT",
        function()
          vim.cmd("vsplit | term goda tree ./...")
        end,
        desc = "Go: goda tree (package deps)",
        ft = "go",
      },

      -- "Who reaches package X" — useful for impact analysis.
      {
        "<leader>cgR",
        function()
          local pkg = vim.fn.input("Package to reach: ")
          if pkg == "" then return end
          vim.cmd("vsplit | term goda reach ./... " .. vim.fn.shellescape(pkg))
        end,
        desc = "Go: goda reach (who imports package?)",
        ft = "go",
      },
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
