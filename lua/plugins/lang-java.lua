return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- jdtls itself requires Java 21+ to *run* (its own JVM).
      -- Projects can still target Java 17 — that's set via the `runtimes`
      -- block below. We resolve both JDKs here:
      --   * jdtls_java_home → Java 21 for jdtls's process
      --   * project_java_17 → Java 17 for project compilation/inlay/etc.
      local function jhome(version)
        local h = vim.fn.trim(vim.fn.system("/usr/libexec/java_home -v " .. version .. " 2>/dev/null"))
        return (h ~= "" and not h:match("error")) and h or nil
      end
      local jdtls_java_home  = jhome(21) or jhome(17) or os.getenv("JAVA_HOME")
      local project_java_17  = jhome(17)
      local project_java_21  = jhome(21)
      opts.jdtls = vim.tbl_deep_extend("force", opts.jdtls or {}, {
        cmd_env = { JAVA_HOME = jdtls_java_home },
      })

      local lombok = vim.fn.expand("~/.local/share/nvim/mason/share/lombok/lombok.jar")
      opts.full_cmd = function(cmd_opts)
        local fname = vim.api.nvim_buf_get_name(0)
        -- LazyVim's `util.lsp.get_root_dir` was removed; use nvim 0.10+ native
        -- `vim.fs.root()` to find the Java project root.
        local root_dir = vim.fs.root(fname ~= "" and fname or 0, {
          "pom.xml",
          "build.gradle",
          "build.gradle.kts",
          "settings.gradle",
          "settings.gradle.kts",
          "mvnw",
          "gradlew",
          ".git",
        }) or vim.fn.getcwd()
        local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
        local cmd = vim.deepcopy(cmd_opts.cmd or { "jdtls" })
        table.insert(cmd, "--jvm-arg=-javaagent:" .. lombok)
        table.insert(cmd, "-data")
        table.insert(cmd, vim.fn.expand("~/.cache/jdtls/workspace/") .. project_name)
        return cmd
      end

      -- Build the runtimes list: include whatever JDKs are actually present.
      -- Java 17 stays the default (project compile target); Java 21 is also
      -- exposed so projects targeting 21 work too.
      local runtimes = {}
      if project_java_17 then
        table.insert(runtimes, { name = "JavaSE-17", path = project_java_17, default = true })
      end
      if project_java_21 then
        table.insert(runtimes, {
          name = "JavaSE-21",
          path = project_java_21,
          default = (project_java_17 == nil),  -- only default if 17 is missing
        })
      end

      opts.settings = vim.tbl_deep_extend("force", opts.settings or {}, {
        java = {
          configuration = {
            runtimes = runtimes,
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
