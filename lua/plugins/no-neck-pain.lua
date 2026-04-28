-- no-neck-pain.nvim — horizontal centering via empty padding buffers.
-- This is the asymmetry-free alternative to zen-mode for "I want my code
-- in the middle of the screen". Unlike zen-mode (which uses a floating
-- backdrop and exposes underlying buffer text on the sides), NNP creates
-- two empty scratch buffers as L/R padding — the sides are uniformly empty
-- regardless of what code is loaded.
--
-- Toggle: <leader>uN. The wrapper also hides chrome (line numbers,
-- signcolumn, cursorline, statusline, mode) on enable and restores them
-- on disable, so the result is "centered + zen-like" in one keystroke.
--
-- Safety: pressing `q` in a NNP padding buffer toggles NNP off (escapes
-- the dead-end scratch buffer). After toggling, focus is forced back to
-- the main code buffer so you don't land in the padding by accident.

-- Per-filetype width: prose / docs (markdown, rst, asciidoc, org, help, ...) need
-- a wider main buffer because tables and long sentences don't fit in a 100-col
-- code-style band. Code stays at 100. Tweak the table or the numbers as needed.
local PROSE_WIDTH = 160
local CODE_WIDTH  = 100
local PROSE_FT = {
  markdown = true,  quarto   = true,  rst      = true,
  asciidoc = true,  org      = true,  vimwiki  = true,
  help     = true,  text     = true,  tex      = true,
}
local function decide_width()
  return PROSE_FT[vim.bo.filetype] and PROSE_WIDTH or CODE_WIDTH
end

-- Detect "tree-like" side panels that confuse NNP's layout calculation.
-- If any are open, close them first so NNP gets a clean single-window state
-- before it inserts both padding buffers.
local function close_sidebars()
  local closed = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      if ft == "neo-tree" or ft == "snacks_layout_box" or ft == "Outline"
         or ft == "trouble" or ft == "Trouble" or ft == "dapui_scopes" then
        pcall(vim.api.nvim_win_close, win, false)
        table.insert(closed, ft)
      end
    end
  end
  return closed
end

local function toggle_nnp()
  -- On enable (about to flip from false → true), auto-close sidebars so the
  -- main code buffer is the only window. NNP then adds true L/R padding.
  if not vim.g._dora_nnp_active then
    local closed = close_sidebars()
    if #closed > 0 then
      vim.notify("NNP: closed sidebars (" .. table.concat(closed, ", ") .. ") to keep layout symmetric",
        vim.log.levels.INFO)
    end
  end

  vim.g._dora_nnp_active = not vim.g._dora_nnp_active
  vim.cmd("NoNeckPain")
  if vim.g._dora_nnp_active then
    -- Resize main buffer to fit the current filetype's needs (prose vs code).
    pcall(vim.cmd, "NoNeckPainResize " .. decide_width())
    vim.g._dora_nnp_saved = {
      number         = vim.o.number,
      relativenumber = vim.o.relativenumber,
      signcolumn     = vim.o.signcolumn,
      cursorline     = vim.o.cursorline,
      laststatus     = vim.o.laststatus,
      showmode       = vim.o.showmode,
    }
    vim.opt.number         = false
    vim.opt.relativenumber = false
    vim.opt.signcolumn     = "no"
    vim.opt.cursorline     = false
    vim.opt.laststatus     = 0
    vim.opt.showmode       = false
  else
    local s = vim.g._dora_nnp_saved or {}
    vim.opt.number         = s.number ~= nil and s.number or true
    vim.opt.relativenumber = s.relativenumber ~= nil and s.relativenumber or true
    vim.opt.signcolumn     = s.signcolumn or "yes"
    vim.opt.cursorline     = s.cursorline ~= nil and s.cursorline or true
    vim.opt.laststatus     = s.laststatus or 3
    vim.opt.showmode       = s.showmode ~= nil and s.showmode or true
  end

  -- After toggling, jump focus to a NON-NNP window. If the cursor happened
  -- to be in a padding buffer (or NNP put it there during enable), this
  -- moves it to a real code buffer. Iterate windows; pick the first whose
  -- buffer's filetype is not "no-neck-pain".
  vim.schedule(function()
    if vim.bo.filetype == "no-neck-pain" then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype ~= "no-neck-pain" then
          vim.api.nvim_set_current_win(win)
          return
        end
      end
    end
  end)
end

return {
  {
    "shortcuts/no-neck-pain.nvim",
    cmd = "NoNeckPain",
    keys = {
      { "<leader>uN", toggle_nnp, desc = "Centered zen (NoNeckPain + chrome off)" },
    },
    init = function()
      -- Escape hatch: in a NNP padding buffer, q closes the whole NNP.
      -- (The padding buffer is filetype "no-neck-pain"; without this, q
      -- starts a macro recording — confusing dead-end.)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "no-neck-pain",
        callback = function(args)
          vim.keymap.set("n", "q", toggle_nnp,
            { buffer = args.buf, desc = "Close NoNeckPain" })
          vim.keymap.set("n", "<Esc>", toggle_nnp,
            { buffer = args.buf, desc = "Close NoNeckPain" })
        end,
      })
    end,
    opts = {
      width = 100,
      autocmds = {
        enableOnVimEnter      = false,
        enableOnTabEnter      = false,
        reloadOnColorSchemeChange = true,
      },
      mappings = {
        enabled = false,
      },
      buffers = {
        setNames = false,
        bo = {
          filetype  = "no-neck-pain",
          buftype   = "nofile",
          bufhidden = "hide",
          buflisted = false,
          swapfile  = false,
        },
        wo = {
          cursorline    = false,
          cursorcolumn  = false,
          number        = false,
          relativenumber= false,
          foldenable    = false,
          list          = false,
        },
        -- Force both L and R padding to be enabled. Some NNP versions only
        -- create one side if the layout already has a non-code window on
        -- the other side. Explicit enabled = true here guards against that.
        left  = { enabled = true },
        right = { enabled = true },
      },
    },
  },
}
