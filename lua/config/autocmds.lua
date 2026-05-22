-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)

-- ============================================================================
-- IDE-style italics on STATIC and ABSTRACT members (like IntelliJ / GoLand).
--
-- IDEA italicizes static fields, static methods and abstract members — info
-- that treesitter can't see (it's semantic, not syntactic). LSP semantic tokens
-- carry the `static` / `abstract` modifiers, which Neovim exposes as the
-- `@lsp.typemod.<type>.<mod>` and `@lsp.mod.<mod>` highlight groups.
--
-- We set ONLY `italic = true` on those groups (no fg): the base colour still
-- comes from the `@lsp.type.<type>` extmark, and Neovim merges the two
-- overlapping highlights, so a static method keeps its colour AND gets italic.
-- Re-applied on every ColorScheme so it survives <leader>uC theme switches and
-- works regardless of theme (the per-theme italic config in colorscheme.lua
-- only covers catppuccin/kanagawa; this is theme-independent).
local function ide_semantic_styles()
  -- (1) STATIC + ABSTRACT members → italic. IDEA italicizes these; treesitter
  -- can't see "static"/"abstract" (semantic, not syntactic) so we ride the LSP
  -- semantic-token groups. Only `italic` is set (no fg) — the colour still
  -- comes from the `@lsp.type.*` extmark and Neovim merges the two.
  for _, g in ipairs({
    "@lsp.typemod.method.static",
    "@lsp.typemod.function.static",
    "@lsp.typemod.property.static",
    "@lsp.typemod.variable.static",
    "@lsp.typemod.method.abstract",
    "@lsp.typemod.class.abstract",
    "@lsp.mod.abstract",
  }) do
    vim.api.nvim_set_hl(0, g, { italic = true })
  end

  -- (2) instance FIELDS → purple, and (3) PARAMETERS → neutral & non-italic.
  -- IDEA's signature is purple fields with plain parameters. rose-pine ships
  -- the opposite (parameters get iris + italic, fields are uncoloured), so on
  -- rose-pine we swap: fields take iris, parameters drop to the body text
  -- colour with no italic. Colours come from the ACTIVE rose-pine variant
  -- (main/dawn/moon), so <leader>uL toggles stay correct. Gated to rose-pine
  -- so other themes (via <leader>uC) keep their own palette.
  if (vim.g.colors_name or ""):match("^rose%-pine") then
    local ok, pal = pcall(require, "rose-pine.palette")
    if ok then
      vim.api.nvim_set_hl(0, "@lsp.type.property", { fg = pal.iris })           -- fields → purple
      vim.api.nvim_set_hl(0, "@lsp.type.parameter", { fg = pal.text })          -- params → neutral, no italic
      vim.api.nvim_set_hl(0, "@variable.parameter", { fg = pal.text })
    end
  end
end

-- Neovide-only rose-pine-dawn polish: keep plugin behavior unchanged, but make
-- floating surfaces, menus and the dashboard read as one soft-glass layer.
local function neovide_soft_glass_highlights()
  if not vim.g.neovide then return end
  if not (vim.g.colors_name or ""):match("^rose%-pine") then return end

  local ok, pal = pcall(require, "rose-pine.palette")
  if not ok then return end

  local surface = pal.surface or pal.base
  local overlay = pal.overlay or surface
  local low = pal.highlight_low or surface
  local med = pal.highlight_med or overlay
  local high = pal.highlight_high or overlay
  local muted = pal.muted or pal.subtle or pal.text
  local set = vim.api.nvim_set_hl

  set(0, "NormalFloat", { fg = pal.text, bg = surface })
  set(0, "FloatBorder", { fg = high, bg = surface })
  set(0, "FloatTitle", { fg = pal.rose, bg = surface })
  set(0, "WinSeparator", { fg = low, bg = pal.base })

  set(0, "Pmenu", { fg = pal.text, bg = surface })
  set(0, "PmenuSel", { fg = pal.text, bg = med })
  set(0, "PmenuSbar", { bg = low })
  set(0, "PmenuThumb", { bg = high })

  set(0, "NoiceCmdlinePopup", { fg = pal.text, bg = surface })
  set(0, "NoiceCmdlinePopupBorder", { fg = pal.iris, bg = surface })
  set(0, "NoiceCmdlineIcon", { fg = pal.iris, bg = surface })
  set(0, "NoiceConfirmBorder", { fg = pal.rose, bg = surface })
  set(0, "NoiceMini", { fg = muted, bg = surface })

  set(0, "BlinkCmpDoc", { fg = pal.text, bg = surface })
  set(0, "BlinkCmpDocBorder", { fg = high, bg = surface })
  set(0, "BlinkCmpDocSeparator", { bg = surface })

  set(0, "NotifyINFOBorder", { fg = pal.foam, bg = surface })
  set(0, "NotifyWARNBorder", { fg = pal.gold, bg = surface })
  set(0, "NotifyERRORBorder", { fg = pal.love, bg = surface })
  set(0, "NotifyDEBUGBorder", { fg = muted, bg = surface })
  set(0, "NotifyTRACEBorder", { fg = pal.iris, bg = surface })
  for _, level in ipairs({ "INFO", "WARN", "ERROR", "DEBUG", "TRACE" }) do
    set(0, "Notify" .. level .. "Body", { fg = pal.text, bg = surface })
  end

  set(0, "SnacksDashboardHeader", { fg = pal.rose })
  set(0, "SnacksDashboardTitle", { fg = pal.foam })
  set(0, "SnacksDashboardDesc", { fg = pal.text })
  set(0, "SnacksDashboardSpecial", { fg = pal.iris })
  set(0, "SnacksDashboardDir", { fg = muted })
  set(0, "SnacksDashboardFooter", { fg = muted })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("user_ide_semantic_styles", { clear = true }),
  -- schedule so this runs AFTER the colorscheme's own synchronous highlight setup
  callback = vim.schedule_wrap(ide_semantic_styles),
})
-- Apply once now in case the colorscheme already loaded before this registered.
vim.schedule(ide_semantic_styles)

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("user_neovide_soft_glass_highlights", { clear = true }),
  callback = vim.schedule_wrap(neovide_soft_glass_highlights),
})
vim.schedule(neovide_soft_glass_highlights)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Disable LazyVim's default `vim.opt_local.spell = true` on markdown / text /
-- gitcommit / typst / plaintex. We delete the entire wrap_spell autogroup so
-- nothing in that registration order can fight us.
pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_wrap_spell")

-- Re-add only the wrap-line behavior (without the spell side-effect).
-- NOTE: markdown is intentionally NOT in this list — see the nowrap autocmd
-- just below for why.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_text_wrap", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = false
  end,
})

-- Force `nowrap` on markdown buffers — REQUIRED for markview table rendering.
-- markview's table renderer bails out when the window has `wrap = true` (its
-- own source comments "BUG, wrap breaks table rendering"). With the global
-- `wrap = true` (set in options.lua), any table wider than the window would
-- soft-wrap and silently fall back to raw `| --- |` text, while narrow tables
-- that fit kept rendering — the "some tables render, some don't" symptom.
-- nowrap lets every table render; the few overly-long prose lines just scroll
-- horizontally. Also kill spell here (markdown isn't in user_text_wrap anymore).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_markdown_nowrap", { clear = true }),
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = false
    -- No column-width guide line on prose — the global colorcolumn=100 (a
    -- vertical line for code line-width) just clutters markdown reading.
    vim.opt_local.colorcolumn = ""
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
