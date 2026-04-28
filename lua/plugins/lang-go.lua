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
  --   2. <leader>cgv → renders full call graph from main(), opens in Preview.app
  --   3. <leader>cgV → call graph focused on the package of the current file
  --   4. macOS Preview.app supports zoom / pan / search — no browser involved
  --
  -- Requires: go-callvis, goda, graphviz (dot). Installed by install.sh.
  --
  -- All commands resolve the Go module root by walking up from the current
  -- buffer until a go.mod is found, so they work regardless of nvim's cwd.
  {
    "olexsmir/gopher.nvim",
    optional = true,
    init = function()
      -- Find Go module root by walking up from the current buffer's directory
      -- until a go.mod file is encountered. Returns the directory containing
      -- go.mod, or nil if none is found.
      _G.__find_go_root = function()
        local file = vim.api.nvim_buf_get_name(0)
        local start = (file ~= "") and vim.fn.fnamemodify(file, ":p:h") or vim.fn.getcwd()
        local found = vim.fs.find({ "go.mod" }, { upward = true, path = start })
        if #found > 0 then return vim.fn.fnamemodify(found[1], ":h") end
        return nil
      end

      -- One-shot go-callvis render: SVG to /tmp + open in Preview.app.
      -- macOS-native, no browser. Preview supports zoom / pan / Cmd-F search.
      -- Returns immediately; renders async and opens Preview on success.
      _G.__go_callvis_render = function(focus)
        local root = _G.__find_go_root()
        if not root then
          vim.notify("go-callvis: no go.mod found in any parent of current file", vim.log.levels.ERROR)
          return
        end
        local stamp = tostring(os.time())
        local out_base = "/tmp/dora-callgraph-" .. stamp        -- without extension
        -- PDF (not SVG): Preview.app does NOT render SVG natively; PDF is its
        -- home format. PDF is also vector, so zooming stays sharp on tiny
        -- function names. Cmd-F still searches text inside the PDF.
        local out_pdf = out_base .. ".pdf"
        local args = {
          "go-callvis",
          "-nostd",
          "-group", "pkg,type",
          "-format", "pdf",
          "-graphviz",                -- run dot to actually render
          "-file", out_base,          -- go-callvis appends .<format>
        }
        if focus and focus ~= "" then
          table.insert(args, "-focus")
          table.insert(args, focus)
        end
        table.insert(args, "./...")
        local label = focus and ("focus=" .. focus) or "full"
        vim.notify(("go-callvis (%s) rendering… (~10-30s first run)"):format(label),
          vim.log.levels.INFO)
        vim.fn.jobstart(args, {
          cwd = root,
          on_stderr = function(_, data)
            local msg = table.concat(data, "\n"):gsub("\n+$", "")
            if msg ~= "" then
              vim.schedule(function() vim.notify("go-callvis: " .. msg, vim.log.levels.WARN) end)
            end
          end,
          on_exit = function(_, code)
            vim.schedule(function()
              if code ~= 0 then
                vim.notify("go-callvis exited with code " .. code, vim.log.levels.ERROR)
                return
              end
              if vim.fn.filereadable(out_pdf) ~= 1 then
                vim.notify("go-callvis finished but " .. out_pdf .. " not found", vim.log.levels.ERROR)
                return
              end
              -- Plain `open <pdf>` lets macOS pick the default PDF handler
              -- (usually Preview). `-a Preview` was unreliable when the user
              -- had a non-default PDF app set.
              vim.fn.jobstart({ "open", out_pdf }, { detach = true })
              vim.notify("Call graph → " .. out_pdf, vim.log.levels.INFO)
            end)
          end,
        })
      end
    end,
    keys = {
      -- Full project call graph: every function from main() down, edges color-coded by pkg.
      {
        "<leader>cgv",
        function() _G.__go_callvis_render(nil) end,
        desc = "Go: full call graph → Preview.app",
        ft = "go",
      },

      -- Focused on the package of the current file.
      {
        "<leader>cgV",
        function()
          local root = _G.__find_go_root()
          if not root then
            vim.notify("go-callvis: no go.mod found in any parent of current file", vim.log.levels.ERROR)
            return
          end
          local pkg_dir = vim.fn.expand("%:p:h")
          local rel = pkg_dir:sub(#root + 2)
          if rel == "" then rel = "." end
          _G.__go_callvis_render(rel)
        end,
        desc = "Go: call graph focused on current package → Preview.app",
        ft = "go",
      },

      -- Module-level dependency tree (lighter, text-based, in nvim buffer).
      {
        "<leader>cgg",
        function()
          local root = _G.__find_go_root()
          if not root then
            vim.notify("no go.mod in any parent — open a file inside a Go module", vim.log.levels.ERROR)
            return
          end
          vim.cmd("vsplit | term cd " .. vim.fn.shellescape(root) .. " && go mod graph | head -200")
        end,
        desc = "Go: module dependency graph",
        ft = "go",
      },

      -- Package-level dependency tree (goda).
      {
        "<leader>cgT",
        function()
          local root = _G.__find_go_root()
          if not root then
            vim.notify("no go.mod in any parent — open a file inside a Go module", vim.log.levels.ERROR)
            return
          end
          vim.cmd("vsplit | term cd " .. vim.fn.shellescape(root) .. " && goda tree ./...")
        end,
        desc = "Go: goda tree (package deps)",
        ft = "go",
      },

      -- "Who reaches package X" — useful for impact analysis.
      {
        "<leader>cgR",
        function()
          local root = _G.__find_go_root()
          if not root then
            vim.notify("no go.mod in any parent — open a file inside a Go module", vim.log.levels.ERROR)
            return
          end
          local pkg = vim.fn.input("Package to reach: ")
          if pkg == "" then return end
          vim.cmd("vsplit | term cd " .. vim.fn.shellescape(root) .. " && goda reach ./... " .. vim.fn.shellescape(pkg))
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
