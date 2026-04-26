return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      local java_home = os.getenv("JAVA_HOME") or vim.fn.trim(vim.fn.system("/usr/libexec/java_home -v 17"))
      opts.jdtls = vim.tbl_deep_extend("force", opts.jdtls or {}, {
        cmd_env = { JAVA_HOME = java_home },
      })

      local lombok = vim.fn.expand("~/.local/share/nvim/mason/share/lombok/lombok.jar")
      opts.full_cmd = function(cmd_opts)
        local fname = vim.api.nvim_buf_get_name(0)
        local root_dir = require("lazyvim.util.lsp").get_root_dir(fname) or vim.fn.getcwd()
        local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
        local cmd = vim.deepcopy(cmd_opts.cmd or { "jdtls" })
        table.insert(cmd, "--jvm-arg=-javaagent:" .. lombok)
        table.insert(cmd, "-data")
        table.insert(cmd, vim.fn.expand("~/.cache/jdtls/workspace/") .. project_name)
        return cmd
      end

      opts.settings = vim.tbl_deep_extend("force", opts.settings or {}, {
        java = {
          configuration = {
            runtimes = {
              {
                name = "JavaSE-17",
                path = java_home,
                default = true,
              },
            },
          },
          inlayHints = {
            parameterNames = { enabled = "all" },
          },
          format = {
            settings = {
              url = vim.fn.expand("~/.config/nvim/google-java-format.xml"),
            },
          },
        },
      })

      return opts
    end,
  },
}
