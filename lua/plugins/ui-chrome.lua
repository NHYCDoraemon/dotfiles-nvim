return {
  -- File tabs (top).
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        mode = "buffers",
        themable = true,
        numbers = "none",
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(_, _, diag)
          local icons = require("lazyvim.config").icons.diagnostics
          local ret = (diag.error and icons.Error .. diag.error .. " " or "")
            .. (diag.warning and icons.Warn .. diag.warning or "")
          return vim.trim(ret)
        end,
        offsets = {
          { filetype = "snacks_layout_box", text = "Project", text_align = "left", separator = true },
          { filetype = "Outline", text = "Structure", text_align = "left", separator = true },
        },
        show_buffer_close_icons = true,
        show_close_icon = false,
        separator_style = "slant",
        always_show_bufferline = true,
        indicator = { style = "underline" },
        modified_icon = "●",
      },
    },
  },

  -- Breadcrumb (sticky path/class/method line).
  {
    "Bekaboo/dropbar.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      -- Interactive pick: each breadcrumb segment gets a letter label;
      -- press the letter to open that segment's dropdown menu.
      { "<leader>;", function() require("dropbar.api").pick() end, desc = "Breadcrumb: pick component" },
      -- Step navigation within a context (function -> next sibling, etc.).
      { "[c", function() require("dropbar.api").goto_context_start() end, desc = "Breadcrumb: goto context start" },
      { "]c", function() require("dropbar.api").select_next_context() end, desc = "Breadcrumb: next context" },
    },
    opts = {
      bar = {
        enable = function(buf, win)
          if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
            return false
          end
          if vim.fn.win_gettype(win) ~= "" then return false end
          local bt = vim.bo[buf].buftype
          if bt ~= "" and bt ~= "acwrite" then return false end
          return vim.bo[buf].buflisted
        end,
        sources = function(buf, _)
          local sources = require("dropbar.sources")
          if vim.bo[buf].filetype == "markdown" then
            return { sources.path, sources.markdown }
          end
          return { sources.path, { get_symbols = function(buff, win, cursor)
            if vim.b[buff].lsp_attached then
              return sources.lsp.get_symbols(buff, win, cursor)
            end
            return sources.treesitter.get_symbols(buff, win, cursor)
          end } }
        end,
      },
      icons = {
        kinds = {
          file_icon  = function(path) return require("nvim-web-devicons").get_icon(path) or "" end,
          folder_icon = "",
        },
        ui = { bar = { separator = "  ", extends = "…" } },
      },
      menu = {
        win_configs = { border = "rounded" },
      },
    },
  },

  -- Sticky scope header at top of editor.
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
    opts = {
      enable = true,
      max_lines = 3,
      min_window_height = 20,
      line_numbers = true,
      multiline_threshold = 1,
      trim_scope = "outer",
      -- "topline" = only redraw when viewport scrolls. Avoids flicker on intra-screen
      -- cursor movement and during smooth-scroll frames.
      mode = "topline",
      separator = "─",
      zindex = 20,
    },
  },

  -- Status bar at bottom.
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = vim.tbl_extend("force", opts.options or {}, {
        theme = "auto",
        globalstatus = true,
        component_separators = "│",
        section_separators = { left = "", right = "" },
        disabled_filetypes = { statusline = { "dashboard", "alpha", "snacks_dashboard" } },
      })

      opts.sections = vim.tbl_extend("force", opts.sections or {}, {
        lualine_a = { { "mode", right_padding = 2 } },
        lualine_b = {
          { "branch" },
          { "diff" },
        },
        lualine_c = {
          { "diagnostics" },
          { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" } },
        },
        lualine_x = {
          {
            function()
              local clients = vim.lsp.get_clients({ bufnr = 0 })
              if #clients == 0 then return "" end
              local names = {}
              for _, c in ipairs(clients) do table.insert(names, c.name) end
              return "LSP: " .. table.concat(names, ",")
            end,
          },
          { "encoding" },
          { "fileformat" },
          { "filetype",  icon_only = true, separator = "", padding = { left = 1, right = 0 } },
        },
        lualine_y = {
          { "progress", separator = " ", padding = { left = 1, right = 0 } },
          { "location", padding = { left = 0, right = 1 } },
        },
        lualine_z = {
          { function() return os.date("%R") end },
        },
      })
      return opts
    end,
  },
}
