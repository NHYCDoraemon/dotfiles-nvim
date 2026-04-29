-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Disable LazyVim's default `vim.opt_local.spell = true` on markdown / text /
-- gitcommit / typst / plaintex. We delete the entire wrap_spell autogroup so
-- nothing in that registration order can fight us.
pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_wrap_spell")

-- Re-add only the wrap-line behavior (without the spell side-effect).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_text_wrap", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = false
  end,
})

-- Mute LSP diagnostics on markdown buffers (marksman / etc. still attach for
-- navigation & completion, but no inline error squiggles).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_markdown_no_diag", { clear = true }),
  pattern = "markdown",
  callback = function(args)
    vim.diagnostic.enable(false, { bufnr = args.buf })
  end,
})

-- ============================================================================
-- Mermaid / PlantUML render keymap (eagerly registered).
-- Putting this in plugin specs (snacks init / etc.) was unreliable because
-- the FileType event sometimes fired before the plugin's init function ran,
-- so <leader>mr never got bound. autocmds.lua loads at startup, before any
-- file-open FileType event, so the binding is always there.
-- ============================================================================
do
  _G.__diagram_preview = _G.__diagram_preview or {}

  local function render_diagram(buf, kind)
    local src = vim.api.nvim_buf_get_name(buf)
    if src == "" then
      vim.notify("Save the file first.", vim.log.levels.WARN)
      return
    end
    local out_path = vim.fn.tempname() .. "_" .. vim.fn.fnamemodify(src, ":t:r") .. ".png"
    local cmd
    if kind == "mermaid" then
      cmd = string.format("mmdc -i %s -o %s -b transparent -t dark",
        vim.fn.shellescape(src), vim.fn.shellescape(out_path))
    elseif kind == "plantuml" then
      cmd = string.format("plantuml -tpng -pipe < %s > %s",
        vim.fn.shellescape(src), vim.fn.shellescape(out_path))
    else
      return
    end

    vim.fn.jobstart({ "sh", "-c", cmd }, {
      on_exit = function(_, code)
        vim.schedule(function()
          if code ~= 0 or vim.fn.filereadable(out_path) ~= 1 then
            vim.notify(kind .. " render failed (exit " .. code .. ")", vim.log.levels.ERROR)
            return
          end
          if vim.g.neovide then
            -- Neovide: image.nvim hijacks .png and renders inline in vsplit.
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
            vim.notify(kind .. " → preview split (Neovide inline)", vim.log.levels.INFO)
          else
            vim.fn.jobstart({ "open", out_path }, { detach = true })
            vim.notify(kind .. " → opened in Preview.app", vim.log.levels.INFO)
          end
        end)
      end,
    })
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("UserDiagramKeys", { clear = true }),
    pattern = { "mermaid", "plantuml" },
    callback = function(args)
      vim.keymap.set("n", "<leader>mr", function()
        render_diagram(args.buf, vim.bo[args.buf].filetype)
      end, { buffer = args.buf, desc = "Diagram: render & preview" })
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("UserDiagramAutoRender", { clear = true }),
    pattern = { "*.mmd", "*.mermaid", "*.puml", "*.plantuml", "*.pu", "*.iuml" },
    callback = function(args)
      local ft = vim.bo[args.buf].filetype
      if ft == "mermaid" or ft == "plantuml" then
        render_diagram(args.buf, ft)
      end
    end,
  })
end

-- Yank highlight: brief flash of the just-yanked region. Default vim duration
-- is 175ms with a low-key gray; bump to 350ms and reuse the colorscheme's
-- `IncSearch` group so the flash inherits whatever theme is active (rose-pine
-- gives a soft pink, kanagawa a warm gold, etc.).
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("dora_yank_highlight", { clear = true }),
  callback = function()
    (vim.hl or vim.highlight).on_yank({ higroup = "IncSearch", timeout = 350 })
  end,
})

-- `q` closes any floating window (goto-preview peek, LSP hover, dap-ui floats,
-- snacks help-style popups, etc.). LazyVim only binds q for a fixed list of
-- filetypes; this catches the rest by detecting `relative != ""` (= floating).
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  group = vim.api.nvim_create_augroup("user_q_closes_floats", { clear = true }),
  callback = function(args)
    local win = vim.api.nvim_get_current_win()
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" then
      vim.keymap.set("n", "q", "<cmd>close<CR>", {
        buffer = args.buf,
        silent = true,
        desc = "Close floating window",
      })
    end
  end,
})
