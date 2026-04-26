return {
  -- Override LazyVim's `gr` LSP keymap to use Snacks picker (floating, no quickfix).
  -- LazyVim.lsp.on_attach() is the framework-supported hook that runs AFTER LazyVim's
  -- own LSP keymap setup, so our buffer-local `gr` cleanly overrides it. Earlier
  -- attempts via `keys` mutation and a plain LspAttach autocmd lost the ordering race.
  {
    "neovim/nvim-lspconfig",
    init = function()
      LazyVim.lsp.on_attach(function(_, buffer)
        vim.keymap.set("n", "gr", function()
          if _G.Snacks and _G.Snacks.picker and _G.Snacks.picker.lsp_references then
            _G.Snacks.picker.lsp_references()
          else
            vim.lsp.buf.references()
          end
        end, { buffer = buffer, desc = "References (picker, no quickfix)", silent = true })
      end)
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
