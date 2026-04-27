-- Inline "X references" above every function / method / class in the buffer.
-- Works for ANY LSP that supports textDocument/references — Go, Rust, Python,
-- TypeScript, Lua, etc. (Java already gets it natively via jdtls codelens, so
-- we exclude .java to avoid double-rendering.)
return {
  {
    "Wansmer/symbol-usage.nvim",
    event = "LspAttach",
    config = function()
      require("symbol-usage").setup({
        -- Render references / definitions / implementations as virtual text
        -- above each symbol declaration (NOT inline at end-of-line — cleaner).
        vt_position = "above",

        -- The text format. Empty count → render nothing (skip).
        text_format = function(symbol)
          local fragments = {}
          if symbol.references then
            local label = symbol.references == 0 and "no usages"
              or (symbol.references == 1 and "1 usage" or symbol.references .. " usages")
            table.insert(fragments, label)
          end
          if symbol.definition then
            table.insert(fragments, symbol.definition .. " defs")
          end
          if symbol.implementation then
            table.insert(fragments, symbol.implementation .. " impls")
          end
          return table.concat(fragments, " · ")
        end,

        -- Which kinds get the lens. Default focuses on top-level constructs.
        kinds = {
          vim.lsp.protocol.SymbolKind.Function,
          vim.lsp.protocol.SymbolKind.Method,
          vim.lsp.protocol.SymbolKind.Class,
          vim.lsp.protocol.SymbolKind.Struct,
          vim.lsp.protocol.SymbolKind.Interface,
        },

        -- Tweak: skip noisy filetypes + already-instrumented Java.
        filetypes = {
          java = { kinds = false },  -- jdtls codelens already shows refs
        },

        -- Throttle requests so big files don't spam the LSP.
        request_pending_text = "···",
      })
    end,
  },
}
