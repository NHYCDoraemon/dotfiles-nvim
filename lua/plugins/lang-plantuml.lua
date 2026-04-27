-- PlantUML (.puml / .plantuml) file support — mirrors lang-mermaid.lua.
--
-- `plantuml` CLI renders .puml → PNG; image.nvim's hijack_file_patterns
-- displays the PNG inline in a side split.
--
-- Workflow:
--   1. Open foo.puml → buffer opens with PlantUML syntax (treesitter highlight)
--   2. <leader>mr     → render to a temp PNG and show in side split
--   3. On :w          → auto-render in background; preview split refreshes
--
-- ```plantuml``` blocks inside markdown render automatically via diagram.nvim.
return {
  -- Filetype + treesitter highlighting for .puml / .plantuml
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.filetype.add({
        extension = {
          puml      = "plantuml",
          plantuml  = "plantuml",
          pu        = "plantuml",
          iuml      = "plantuml",
        },
      })
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "puppet" })  -- closest existing parser; plantuml-specific parser optional
    end,
  },

  -- Render keymap + auto-render-on-save autocmd. Reuses _G.__diagram_preview
  -- across mermaid + plantuml so we never stack multiple preview splits.
  {
    "folke/snacks.nvim",
    init = function()
      _G.__diagram_preview = _G.__diagram_preview or {}

      local function render_plantuml(buf)
        buf = buf or vim.api.nvim_get_current_buf()
        local src = vim.api.nvim_buf_get_name(buf)
        if src == "" or not src:match("%.p?u?ml?$") then
          vim.notify("Not a .puml/.plantuml file", vim.log.levels.WARN)
          return
        end
        local out_path = vim.fn.tempname() .. "_" .. vim.fn.fnamemodify(src, ":t:r") .. ".png"
        -- plantuml -pipe < SRC > OUT.png
        local cmd = string.format(
          "plantuml -tpng -pipe < %s > %s",
          vim.fn.shellescape(src),
          vim.fn.shellescape(out_path)
        )
        vim.fn.jobstart({ "sh", "-c", cmd }, {
          on_exit = function(_, code)
            vim.schedule(function()
              if code ~= 0 then
                vim.notify("plantuml render failed (exit " .. code .. ")", vim.log.levels.ERROR)
                return
              end
              if vim.fn.filereadable(out_path) ~= 1 then return end

              -- Same dual strategy as mermaid: Neovide → inline split,
              -- terminal → macOS Preview.app.
              if vim.g.neovide then
                local existing = _G.__diagram_preview[buf]
                if existing and vim.api.nvim_win_is_valid(existing) then
                  vim.api.nvim_win_call(existing, function()
                    vim.cmd("edit! " .. vim.fn.fnameescape(out_path))
                  end)
                else
                  vim.cmd("vsplit " .. vim.fn.fnameescape(out_path))
                  _G.__diagram_preview[buf] = vim.api.nvim_get_current_win()
                  vim.cmd("wincmd p")
                end
                vim.notify("PlantUML → preview split (Neovide inline)", vim.log.levels.INFO)
              else
                vim.fn.jobstart({ "open", out_path }, { detach = true })
                vim.notify("PlantUML → opened in Preview.app", vim.log.levels.INFO)
              end
            end)
          end,
        })
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserPlantumlKeys", { clear = true }),
        pattern = "plantuml",
        callback = function(args)
          vim.keymap.set("n", "<leader>mr", function() render_plantuml(args.buf) end, {
            buffer = args.buf,
            desc = "PlantUML: render & preview",
          })
        end,
      })

      vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("UserPlantumlAutoRender", { clear = true }),
        pattern = { "*.puml", "*.plantuml", "*.pu", "*.iuml" },
        callback = function(args) render_plantuml(args.buf) end,
      })
    end,
  },
}
