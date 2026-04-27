-- Mermaid (.mmd) file support.
--
-- mermaid-cli (mmdc) renders .mmd → PNG; Snacks.image then displays the PNG
-- inline (Neovide / Ghostty 1.3+ with kitty image protocol).
--
-- Workflow:
--   1. Open  foo.mmd  → buffer opens with Mermaid syntax (treated as text + ts highlight)
--   2. <leader>mr     → render to /tmp/<basename>.png and show in a floating image
--   3. On :w          → auto-render in background; the floating preview refreshes
--
-- Same logic also targets ```mermaid``` blocks inside markdown via render-markdown.
return {
  -- Filetype + treesitter highlighting for .mmd
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.filetype.add({ extension = { mmd = "mermaid", mermaid = "mermaid" } })
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "mermaid" })
    end,
  },

  -- Mermaid render keymap + auto-render-on-save autocmd. No new plugin
  -- dependency — just thin glue around mmdc + Snacks.image.
  {
    "folke/snacks.nvim",
    init = function()
      -- Track the preview window per source buffer so re-render reuses the
      -- same split instead of stacking new ones.
      _G.__mermaid_preview = _G.__mermaid_preview or {}

      local function render_mermaid(buf)
        buf = buf or vim.api.nvim_get_current_buf()
        local src = vim.api.nvim_buf_get_name(buf)
        if src == "" or (not src:match("%.mmd$") and not src:match("%.mermaid$")) then
          vim.notify("Not a .mmd file — open the source mermaid file first.", vim.log.levels.WARN)
          return
        end
        local out_path = vim.fn.tempname() .. "_" .. vim.fn.fnamemodify(src, ":t:r") .. ".png"
        local cmd = string.format("mmdc -i %s -o %s -b transparent -t dark",
          vim.fn.shellescape(src), vim.fn.shellescape(out_path))
        vim.fn.jobstart(cmd, {
          on_exit = function(_, code)
            vim.schedule(function()
              if code ~= 0 then
                vim.notify("mmdc render failed (exit " .. code .. ")", vim.log.levels.ERROR)
                return
              end
              if vim.fn.filereadable(out_path) ~= 1 then return end

              -- Open the PNG in a side split. image.nvim's `hijack_file_patterns`
              -- intercepts .png buffers and renders them as images in-place.
              -- Reuse the same split on subsequent renders so we don't stack windows.
              local existing = _G.__mermaid_preview[buf]
              if existing and vim.api.nvim_win_is_valid(existing) then
                vim.api.nvim_win_call(existing, function()
                  vim.cmd("edit! " .. vim.fn.fnameescape(out_path))
                end)
              else
                vim.cmd("vsplit " .. vim.fn.fnameescape(out_path))
                _G.__mermaid_preview[buf] = vim.api.nvim_get_current_win()
                vim.cmd("wincmd p")  -- jump back to source so user keeps editing
              end
              vim.notify("Mermaid rendered → preview split", vim.log.levels.INFO)
            end)
          end,
        })
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserMermaidKeys", { clear = true }),
        pattern = { "mermaid" },
        callback = function(args)
          vim.keymap.set("n", "<leader>mr", function() render_mermaid(args.buf) end, {
            buffer = args.buf,
            desc = "Mermaid: render & preview",
          })
          vim.keymap.set("n", "<leader>mR", function()
            -- Force re-render even if file didn't change
            vim.cmd("write!")
            render_mermaid(args.buf)
          end, { buffer = args.buf, desc = "Mermaid: force re-render" })
        end,
      })

      -- Auto-render on save for .mmd files (silent — only notify on error).
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("UserMermaidAutoRender", { clear = true }),
        pattern = { "*.mmd", "*.mermaid" },
        callback = function(args) render_mermaid(args.buf) end,
      })
    end,
  },
}
