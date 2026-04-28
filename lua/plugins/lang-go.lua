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

      -- Read the `module ...` line from go.mod at <root>/go.mod and return
      -- the module path (e.g. "github.com/NHYCDoraemon/dora"), or nil.
      _G.__read_go_module = function(root)
        local fp = root .. "/go.mod"
        local fd = io.open(fp, "r")
        if not fd then return nil end
        for line in fd:lines() do
          local m = line:match("^%s*module%s+(%S+)")
          if m then fd:close(); return m end
        end
        fd:close()
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
          -- CHA (Class Hierarchy Analysis) sees interface calls. Default
          -- "static" only catches concrete-receiver calls, which misses
          -- ~all of dora's port-and-adapter graph (everything goes through
          -- interfaces). Trade: CHA may over-connect (shows all possible
          -- impls); RTA is more precise but slower. CHA is the sweet spot.
          "-algo", "cha",
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
              -- Three artefacts on disk now:
              --   <base>.gv   raw DOT source — best for feeding an LLM
              --   <base>.pdf  rendered, opens in Preview.app for humans
              --   <base>.svg  rendered SVG (we render from the .gv via `dot`)
              -- We launch Preview with the PDF and ALSO kick off SVG render
              -- in parallel — by the time you switch to the LLM tab, both
              -- text formats are on disk.
              local out_gv  = out_base .. ".gv"
              local out_svg = out_base .. ".svg"
              vim.fn.jobstart({ "dot", "-Tsvg", out_gv, "-o", out_svg }, { detach = true })
              vim.fn.jobstart({ "open", out_pdf }, { detach = true })
              -- Remember latest output for <leader>cgy / <leader>cgY one-key
              -- yank-to-clipboard (defined in keys = {} below).
              _G.__go_callvis_last = { gv = out_gv, svg = out_svg, pdf = out_pdf }
              vim.notify(table.concat({
                "Call graph rendered:",
                "  PDF (view):  " .. out_pdf,
                "  SVG (text):  " .. out_svg,
                "  DOT (LLM):   " .. out_gv,
                "",
                "<leader>cgy = copy DOT to clipboard (paste into AI)",
                "<leader>cgY = copy SVG to clipboard",
              }, "\n"), vim.log.levels.INFO, { title = "go-callvis", timeout = 8000 })
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

      -- Yank the latest call-graph DOT source to the system clipboard.
      -- Workflow: cgv/cgV → wait for "rendered" notify → cgy → paste into AI.
      {
        "<leader>cgy",
        function()
          local last = _G.__go_callvis_last
          if not last or not last.gv or vim.fn.filereadable(last.gv) ~= 1 then
            vim.notify("No call graph generated yet — press <leader>cgv or <leader>cgV first", vim.log.levels.WARN)
            return
          end
          local fd = io.open(last.gv, "r")
          if not fd then
            vim.notify("Failed to read " .. last.gv, vim.log.levels.ERROR)
            return
          end
          local content = fd:read("*a")
          fd:close()
          vim.fn.setreg("+", content)
          vim.notify(("Copied DOT graph to clipboard (%d chars). Paste into your AI."):format(#content),
            vim.log.levels.INFO, { title = "go-callvis" })
        end,
        desc = "Go: yank latest call-graph DOT to clipboard (for AI)",
        ft = "go",
      },

      -- Same as cgy but copies SVG instead of DOT. Use this if your AI tool
      -- prefers SVG (rare — most LLMs handle DOT better).
      {
        "<leader>cgY",
        function()
          local last = _G.__go_callvis_last
          if not last or not last.svg or vim.fn.filereadable(last.svg) ~= 1 then
            vim.notify("No SVG yet — wait a moment after cgv/cgV (dot needs ~1s to render)", vim.log.levels.WARN)
            return
          end
          local fd = io.open(last.svg, "r")
          if not fd then
            vim.notify("Failed to read " .. last.svg, vim.log.levels.ERROR)
            return
          end
          local content = fd:read("*a")
          fd:close()
          vim.fn.setreg("+", content)
          vim.notify(("Copied SVG graph to clipboard (%d chars)."):format(#content),
            vim.log.levels.INFO, { title = "go-callvis" })
        end,
        desc = "Go: yank latest call-graph SVG to clipboard",
        ft = "go",
      },

      -- Focused on the package of the current file. go-callvis -focus expects
      -- a package NAME or full import path; relative paths fail with
      -- "focus failed: <nil>". We compute the full import path from go.mod
      -- module + relative dir.
      {
        "<leader>cgV",
        function()
          local root = _G.__find_go_root()
          if not root then
            vim.notify("go-callvis: no go.mod found in any parent of current file", vim.log.levels.ERROR)
            return
          end
          local mod = _G.__read_go_module(root)
          if not mod then
            vim.notify("go-callvis: couldn't read `module` line from " .. root .. "/go.mod", vim.log.levels.ERROR)
            return
          end
          local pkg_dir = vim.fn.expand("%:p:h")
          local rel = pkg_dir:sub(#root + 2)            -- strip root + "/"
          local import_path = (rel == "") and mod or (mod .. "/" .. rel)
          _G.__go_callvis_render(import_path)
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
