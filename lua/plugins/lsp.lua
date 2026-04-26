return {
  -- Force LSP pickers (gd / gr / gI / gy / symbols) to use the same floating
  -- layout as <leader>ff / <leader>fg. Snacks' built-in defaults for these
  -- sources mark them with auto_confirm + reuse_win, which (combined with our
  -- edgy.nvim config) end up rendering the picker as a left-side panel.
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          lsp_references       = { layout = { preset = "default" }, auto_confirm = false },
          lsp_definitions      = { layout = { preset = "default" }, auto_confirm = false },
          lsp_implementations  = { layout = { preset = "default" }, auto_confirm = false },
          lsp_type_definitions = { layout = { preset = "default" }, auto_confirm = false },
          lsp_declarations     = { layout = { preset = "default" }, auto_confirm = false },
          lsp_incoming_calls   = { layout = { preset = "default" }, auto_confirm = false },
          lsp_outgoing_calls   = { layout = { preset = "default" }, auto_confirm = false },
          lsp_symbols          = { layout = { preset = "default" } },
          lsp_workspace_symbols= { layout = { preset = "default" } },
        },
      },
    },
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
