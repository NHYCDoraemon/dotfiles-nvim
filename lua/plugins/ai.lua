-- Avante.nvim — AI assistant.
--
-- Provider strategy: use Avante's built-in `openai` provider directly with
-- a SiliconFlow endpoint override. Cleaner than `__inherited_from = "openai"`
-- with custom name — avoids edge cases in provider resolution.
--
-- Tool-calling is DISABLED (`disable_tools = true`) at the provider level
-- because DeepSeek via SiliconFlow doesn't reliably implement OpenAI's
-- function-calling spec; agentic mode tries tool calls → response parsing
-- hangs → prompt_input deadlocks.
return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    build = "make",
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-mini/mini.icons",
      "zbirenbaum/copilot.lua",
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = { default = { embed_image_as_base64 = false, prompt_for_file_name = false } },
      },
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = { file_types = { "markdown", "Avante" } },
        ft = { "markdown", "Avante" },
      },
    },
    opts = {
      provider = "openai",
      providers = {
        openai = {
          endpoint     = "https://api.siliconflow.cn/v1",
          model        = "deepseek-ai/DeepSeek-V4-Flash",
          api_key_name = "SILICONFLOW_API_KEY",
          disable_tools = true,  -- DeepSeek tool-call format isn't OpenAI-spec — turn off
          extra_request_body = {
            temperature = 0,
            max_tokens  = 8192,
          },
        },
      },
      behaviour = {
        auto_suggestions = false,
        auto_set_highlight_group = true,
        auto_set_keymaps = true,
        auto_apply_diff_after_generation = false,
        support_paste_from_clipboard = true,
      },
      windows = {
        width = 50,  -- prevents E36 'not enough room' from selected_code_container
        sidebar_header = { rounded = true, align = "center" },
        ask  = { floating = true, start_insert = true, border = "rounded" },
        edit = { border = "rounded", start_insert = true },
      },
      mappings = {
        ask     = "<leader>aa",
        edit    = "<leader>ae",
        refresh = "<leader>ar",
        toggle  = { default = "<leader>at" },
      },
    },
  },
}
