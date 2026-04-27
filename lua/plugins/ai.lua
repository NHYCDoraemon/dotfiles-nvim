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
      provider = "siliconflow",
      -- DeepSeek via SiliconFlow doesn't reliably implement OpenAI tool-calling,
      -- so default `agentic` mode hangs / shows empty UI. Force legacy chat mode.
      mode = "legacy",
      providers = {
        siliconflow = {
          __inherited_from = "openai",
          api_key_name = "SILICONFLOW_API_KEY",
          endpoint = "https://api.siliconflow.cn/v1",
          model = "deepseek-ai/DeepSeek-V4-Flash",
          disable_tools = true,  -- explicitly skip tool-use; legacy chat only
          extra_request_body = {
            temperature = 0,
            max_tokens = 8192,
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
        width = 35,
        sidebar_header = { rounded = true, align = "center" },
        ask = { floating = true, start_insert = true, border = "rounded" },
        edit = { border = "rounded", start_insert = true },
      },
      mappings = {
        ask    = "<leader>aa",
        edit   = "<leader>ae",
        refresh = "<leader>ar",
        toggle = { default = "<leader>at" },
      },
    },
  },
}
