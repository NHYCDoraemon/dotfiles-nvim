-- Log file viewing — auto-highlighting + live tail + level filter.
return {
  -- Auto-highlight for log files: timestamps, log levels (INFO/WARN/ERROR/
  -- DEBUG/TRACE/FATAL), IP addresses, file paths, hex hashes, exceptions,
  -- HTTP method+status, JSON content within lines, etc.
  --
  -- Activates on:
  --   * filetype `log` (vim's built-in detection for .log files)
  --   * any buffer where extension is .log / .out / .err / log_*
  --   * use `:LogHighlight` to force-enable on plain .txt that's actually a log
  {
    "fei6409/log-highlight.nvim",
    event = { "BufReadPost *.log", "BufReadPost *.out", "BufReadPost *.err" },
    cmd = { "LogHighlight" },
    opts = {
      extension = { "log", "out", "err" },
      pattern = {
        "/var/log/.*",
        "/tmp/.*%.log",
        ".*%.log%.%d+",                 -- rotated logs: app.log.1
        ".*%-%d%d%d%d%-%d%d%-%d%d.*",   -- date-stamped log files
      },
    },
  },

  -- Quick log workflow keymaps + tail-follow command.
  {
    "folke/snacks.nvim",  -- piggyback on an always-loaded plugin
    init = function()
      -- :LogTail <file> — follow a log live in a bottom split.
      -- Uses `tail -F` (capital F = follow rotated/recreated files).
      vim.api.nvim_create_user_command("LogTail", function(opts)
        local file = opts.args ~= "" and opts.args or vim.fn.expand("%:p")
        if file == "" or vim.fn.filereadable(file) == 0 then
          vim.notify("No file to tail. Pass a path or open a log first.", vim.log.levels.WARN)
          return
        end
        vim.cmd("botright 15split | term tail -F " .. vim.fn.shellescape(file))
      end, {
        nargs = "?",
        complete = "file",
        desc = "Follow log file (tail -F) in bottom split",
      })

      -- Filetype-scoped keymaps — only fire on log buffers, no global pollution.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserLogKeys", { clear = true }),
        pattern = "log",
        callback = function(args)
          local buf = args.buf

          -- <leader>lt — tail-follow this log live in bottom split
          vim.keymap.set("n", "<leader>lt", "<cmd>LogTail<CR>", {
            buffer = buf,
            desc = "Log: tail -F current file (live follow)",
          })

          -- <leader>le — show only ERROR / FATAL / EXCEPTION lines via Snacks picker
          vim.keymap.set("n", "<leader>le", function()
            Snacks.picker.lines({ pattern = "ERROR|FATAL|EXCEPTION|panic|TRACE" })
          end, { buffer = buf, desc = "Log: errors only (line picker)" })

          -- <leader>lw — warnings
          vim.keymap.set("n", "<leader>lw", function()
            Snacks.picker.lines({ pattern = "WARN|WARNING" })
          end, { buffer = buf, desc = "Log: warnings only" })

          -- <leader>lf — fuzzy line picker for free-form filtering
          vim.keymap.set("n", "<leader>lf", function() Snacks.picker.lines() end,
            { buffer = buf, desc = "Log: fuzzy line filter" })

          -- ]e / [e — jump to next/prev ERROR line
          vim.keymap.set("n", "]e", function() vim.fn.search("ERROR\\|FATAL\\|EXCEPTION\\|panic", "W") end,
            { buffer = buf, desc = "Log: next error" })
          vim.keymap.set("n", "[e", function() vim.fn.search("ERROR\\|FATAL\\|EXCEPTION\\|panic", "bW") end,
            { buffer = buf, desc = "Log: prev error" })

          -- Make log buffers readonly by default to prevent accidental edits;
          -- keep wrap on so long stack traces fit.
          vim.bo[buf].readonly = false  -- still allow :w in case user wants it
          vim.wo.wrap = true
          vim.wo.linebreak = true
        end,
      })
    end,
  },
}
