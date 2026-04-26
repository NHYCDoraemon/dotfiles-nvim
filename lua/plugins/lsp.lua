return {
  -- Override LazyVim's `gr` LSP keymap to use Snacks picker (floating, no quickfix).
  -- We use a direct LspAttach autocmd that runs *after* LazyVim's keymap setup and
  -- forcibly sets a buffer-local `gr`. This is more reliable than mutating LazyVim's
  -- keymap list (which had ordering issues with the resolver).
  {
    "neovim/nvim-lspconfig",
    init = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserGrPickerOverride", { clear = true }),
        callback = function(args)
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(args.buf) then return end
            vim.keymap.set("n", "gr", function()
              if _G.Snacks and _G.Snacks.picker and _G.Snacks.picker.lsp_references then
                _G.Snacks.picker.lsp_references()
              else
                vim.lsp.buf.references()
              end
            end, { buffer = args.buf, desc = "References (picker)", silent = true })
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
