return {
  -- Override LazyVim's `gr` LSP keymap to use Snacks picker (floating, no quickfix).
  -- We use plain nvim autocmds (no LazyVim helper — `LazyVim.lsp.on_attach` is
  -- deprecated and crashes during init because its deprecation notifier needs Snacks).
  -- vim.schedule defers our keymap.set to AFTER LazyVim's LSP keymap setup runs,
  -- so the buffer-local override cleanly wins. BufEnter re-applies as a safety net.
  {
    "neovim/nvim-lspconfig",
    init = function()
      local function set_picker_gr(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) then return end
        vim.keymap.set("n", "gr", function()
          if _G.Snacks and _G.Snacks.picker and _G.Snacks.picker.lsp_references then
            _G.Snacks.picker.lsp_references()
          else
            vim.lsp.buf.references()
          end
        end, { buffer = bufnr, desc = "References (picker, no quickfix)", silent = true })
      end

      local grp = vim.api.nvim_create_augroup("UserGrPickerOverride", { clear = true })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = grp,
        callback = function(args)
          vim.schedule(function() set_picker_gr(args.buf) end)
        end,
      })

      vim.api.nvim_create_autocmd("BufEnter", {
        group = grp,
        callback = function(args)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf)
              and #vim.lsp.get_clients({ bufnr = args.buf }) > 0
            then
              set_picker_gr(args.buf)
            end
          end)
        end,
      })
    end,
  },

  -- Replace pyright with basedpyright in the Python extra.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = { enabled = false },
        basedpyright = {
          settings = {
            basedpyright = {
              analysis = {
                typeCheckingMode = "basic",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
                inlayHints = {
                  variableTypes = true,
                  callArgumentNames = true,
                  functionReturnTypes = true,
                  genericTypes = false,
                },
              },
            },
          },
        },
        gopls = {
          settings = {
            gopls = {
              hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                compositeLiteralTypes = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
              analyses = {
                shadow = true,
                unusedparams = true,
                useany = true,
              },
              staticcheck = true,
              gofumpt = true,
            },
          },
        },
        vtsls = {
          settings = {
            typescript = {
              inlayHints = {
                parameterNames = { enabled = "all" },
                parameterTypes = { enabled = true },
                variableTypes = { enabled = true },
                propertyDeclarationTypes = { enabled = true },
                functionLikeReturnTypes = { enabled = true },
                enumMemberValues = { enabled = true },
              },
            },
            javascript = {
              inlayHints = {
                parameterNames = { enabled = "all" },
                parameterTypes = { enabled = true },
                variableTypes = { enabled = true },
              },
            },
          },
        },
      },
    },
  },

  -- Enable inlay hints + codelens globally on LspAttach.
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then return end
          if client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          end
          if client:supports_method("textDocument/codeLens") then
            vim.lsp.codelens.refresh({ bufnr = args.buf })
            vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
              buffer = args.buf,
              callback = function() vim.lsp.codelens.refresh({ bufnr = args.buf }) end,
            })
          end
        end,
      })
      return opts
    end,
  },
}
