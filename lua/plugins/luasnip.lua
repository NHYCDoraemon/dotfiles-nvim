-- Pre-warm LuaSnip's vscode snippet index at startup instead of on your first
-- real jump/edit.
--
-- Root cause (confirmed via `sample` on a live hang + reading LuaSnip's
-- source, not guessed): LazyVim's luasnip extra calls
-- `require("luasnip.loaders.from_vscode").lazy_load()` with no `paths`,
-- which resolves manifests via `vim.api.nvim_get_runtime_file("package.json",
-- true)` — a scan of the ENTIRE runtimepath (every installed plugin's
-- directory, twice — once for package.json, once for package.jsonc). With
-- 100+ plugins that's thousands of filereadable()/stat()/access() calls, done
-- SYNCHRONOUSLY on the nvim main thread. LazyVim hooks this to the FIRST
-- FileType event of the session, so it silently froze the UI for several
-- seconds the first time any filetype loaded — which looked exactly like a
-- jump (gd/gr) "hanging", because that's usually when you open your first
-- real file.
--
-- Fix: run the same lazy_load() call proactively right after VimEnter
-- (deferred slightly so it doesn't compete with startup itself), so the scan
-- happens while you're looking at the dashboard, not mid-navigation. Calling
-- it again later (LazyVim's own FileType-triggered call still fires) is a
-- cheap no-op — LuaSnip caches which manifests it already indexed.
return {
  {
    "L3MON4D3/LuaSnip",
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          vim.defer_fn(function()
            require("luasnip.loaders.from_vscode").lazy_load()
          end, 100)
        end,
      })
    end,
  },
}
