-- AI assistant — CodeCompanion.nvim.
--
-- We migrated away from Avante.nvim because of architectural fragility:
-- Avante creates a nested `selected_code_container` split inside its sidebar
-- which throws E36 'not enough room' on any non-huge window — there's no
-- reliable opt-out (without_selection runs after render, mode/disable_tools
-- toggles produce other deadlocks). CodeCompanion uses a single chat buffer,
-- no nested splits — no E36, no prompt_input deadlock.
--
-- Provider: SiliconFlow's OpenAI-compatible endpoint, model DeepSeek-V4-Flash.
-- Set `SILICONFLOW_API_KEY` in your shell rc.
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
      "CodeCompanionCmd",
    },
    keys = {
      { "<leader>aa", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "AI: chat (toggle)" },
      { "<leader>ac", "<cmd>CodeCompanionChat Add<cr>",     mode = { "v" },      desc = "AI: add selection to chat" },
      { "<leader>ae", "<cmd>CodeCompanion<cr>",             mode = { "v" },      desc = "AI: inline edit selection" },
      { "<leader>ap", "<cmd>CodeCompanionActions<cr>",      mode = { "n", "v" }, desc = "AI: actions palette" },
    },
    opts = {
      adapters = {
        -- Define a SiliconFlow adapter by extending the built-in
        -- `openai_compatible` template — same OpenAI chat-completion API,
        -- just pointed at SiliconFlow's endpoint.
        http = {
          siliconflow = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url     = "https://api.siliconflow.cn",
                -- `cmd:` prefix tells CodeCompanion to RUN this as a shell
                -- command and use stdout as the value. We invoke an interactive
                -- zsh (`-ic`) so that ~/.zshrc is sourced — this is needed
                -- because GUI apps like Neovide launched from Spotlight / Dock
                -- DON'T inherit shell env vars. Without `cmd:`, the literal
                -- string "SILICONFLOW_API_KEY" gets sent as the token → 401.
                api_key = "cmd:zsh -ic 'echo $SILICONFLOW_API_KEY'",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = { default = "deepseek-ai/DeepSeek-V4-Flash" },
              },
            })
          end,
        },
      },

      strategies = {
        chat   = { adapter = "siliconflow" },
        inline = { adapter = "siliconflow" },
        cmd    = { adapter = "siliconflow" },
      },

      display = {
        chat = {
          window = {
            layout   = "vertical",   -- side panel; "horizontal" / "float" / "buffer" alternatives
            width    = 0.4,           -- 40% of screen width
            height   = 0.9,
            border   = "rounded",
            relative = "editor",
            opts = { signcolumn = "no", spell = false, wrap = true },
          },
          show_settings = false,
          show_token_count = true,
          start_in_insert_mode = true,
        },
        action_palette = {
          provider = "default",     -- can be "telescope" / "snacks"
          opts     = { show_default_actions = true, show_default_prompt_library = true },
        },
        diff = {
          enabled  = true,
          provider = "default",
        },
      },

      opts = {
        log_level = "ERROR",
        send_code = true,            -- include selected code automatically when invoked from visual mode
      },
    },
  },
}
