return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- jdtls itself requires Java 21+ to *run* (its own JVM).
      -- Projects can still target Java 17 — that's set via the `runtimes`
      -- block below. We resolve both JDKs here:
      --   * jdtls_java_home → Java 21 for jdtls's process
      --   * project_java_17 → Java 17 for project compilation/inlay/etc.
      -- Exact version-family query (e.g. `-v 17` matches only 17.x). Used for
      -- the project `runtimes` list, where we want to label each JDK precisely.
      local function jhome(version)
        local h = vim.fn.trim(vim.fn.system("/usr/libexec/java_home -v " .. version .. " 2>/dev/null"))
        return (h ~= "" and not h:match("error")) and h or nil
      end
      -- "version or newer" query (the trailing `+`). jdtls's own JVM needs 21+,
      -- so pick the NEWEST installed JDK >= 21 — a machine with JDK 25 (but no
      -- 21) must still resolve here. `jhome(21)` alone would miss 25 and fall
      -- back to Java 17, which is too old to launch jdtls.
      local function jhome_min(version)
        local h = vim.fn.trim(vim.fn.system("/usr/libexec/java_home -v " .. version .. "+ 2>/dev/null"))
        return (h ~= "" and not h:match("error")) and h or nil
      end
      local jdtls_java_home  = jhome_min(21) or os.getenv("JAVA_HOME")
      local project_java_17  = jhome(17)
      local project_java_21  = jhome(21)
      opts.jdtls = vim.tbl_deep_extend("force", opts.jdtls or {}, {
        cmd_env = { JAVA_HOME = jdtls_java_home },
      })

      -- Keep core jdtls navigation isolated from optional Java DAP/test
      -- extensions. The current Mason java-test bundle layout makes LazyVim
      -- pass non-OSGi jars to jdtls, which causes bundle-load errors during
      -- initialization and can break definitions/references/import navigation.
      opts.dap = false
      opts.dap_main = false
      opts.test = false

      local lombok = vim.fn.expand("~/.local/share/nvim/mason/share/lombok/lombok.jar")

      -- Find the multi-module ROOT pom, not the nearest one.
      --
      -- vim.fs.root() with "pom.xml" returns the closest pom — for
      -- iam-center/iam-admin-service/.../Foo.java it returns
      -- iam-admin-service/pom.xml. jdtls then treats iam-admin-service as a
      -- standalone project, loses access to sibling modules (iam-common-persistence)
      -- and to dependencyManagement defined in the parent pom — so transitive
      -- deps like mybatis-plus & MapperScan show "cannot be resolved".
      --
      -- Strategy: keep walking up while the pom is a child (has <parent>) AND
      -- the directory above also has a pom.xml. The aggregator pom usually has
      -- <modules> instead of <parent>.
      local function find_maven_root(start)
        local dir = vim.fs.dirname(start)
        local root = nil
        while dir and dir ~= "/" and dir ~= "" do
          local pom = dir .. "/pom.xml"
          if vim.fn.filereadable(pom) == 1 then
            root = dir
            -- Stop only if this pom has <modules> (aggregator) OR if no pom
            -- exists one level up — i.e. we've reached the top.
            local content = table.concat(vim.fn.readfile(pom, "", 200), "\n")
            if content:find("<modules>", 1, true) then
              return dir  -- aggregator found, this is the real root
            end
          end
          dir = vim.fs.dirname(dir)
        end
        return root  -- highest pom we saw, or nil if none
      end

      opts.full_cmd = function(cmd_opts)
        local fname = vim.api.nvim_buf_get_name(0)
        local search_from = fname ~= "" and fname or vim.fn.getcwd()

        local root_dir = find_maven_root(search_from)
          or vim.fs.root(fname ~= "" and fname or 0, {
            "build.gradle", "build.gradle.kts",
            "settings.gradle", "settings.gradle.kts",
            "mvnw", "gradlew", ".git",
          })
          or vim.fn.getcwd()

        local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
        local cmd = vim.deepcopy(cmd_opts.cmd or { "jdtls" })
        local has_xmx = false
        local has_lombok_agent = false
        for _, arg in ipairs(cmd) do
          if type(arg) == "string" then
            if arg:find("lombok%.jar", 1, false) then
              has_lombok_agent = true
            end
            if arg:find("Xmx", 1, false) then
              has_xmx = true
            end
          end
        end
        if not has_xmx then
          table.insert(cmd, "--jvm-arg=-Xmx4g")
        end
        if not has_lombok_agent and vim.fn.filereadable(lombok) == 1 then
          table.insert(cmd, "--jvm-arg=-javaagent:" .. lombok)
        end

        local workspace = vim.fn.expand("~/.cache/jdtls/workspace/") .. project_name
        local in_use = vim.fn.system({ "pgrep", "-f", "-data " .. workspace })
        if vim.v.shell_error == 0 and vim.fn.trim(in_use) ~= "" then
          workspace = workspace .. "-" .. vim.fn.getpid()
        end

        table.insert(cmd, "-data")
        table.insert(cmd, workspace)
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

      -- Append Spring Boot Tools jdt-extension jars to jdtls bundles.
      -- These bundles teach jdtls about Spring annotations so the Spring Boot
      -- LS (started separately by lang-java-spring.lua) can talk to jdtls.
      -- Hardcoded glob keeps this independent of spring-boot.nvim load order.
      -- The Mason package is `vscode-spring-boot-tools` (upstream vscode-spring-boot).
      opts.bundles = opts.bundles or {}
      local spring_pkg_root = vim.fn.expand("~/.local/share/nvim/mason/packages/vscode-spring-boot-tools")
      for _, sub in ipairs({ "/extension/jars", "/extension/language-server" }) do
        local dir = spring_pkg_root .. sub
        if vim.fn.isdirectory(dir) == 1 then
          for _, jar in ipairs(vim.split(vim.fn.glob(dir .. "/*.jar"), "\n", { trimempty = true })) do
            -- The language-server jar is NOT a JDT extension; only add jars
            -- under /extension/jars/ to opts.bundles. (Kept the loop generic
            -- because some upstream releases ship jdt extensions in the LS dir.)
            if sub == "/extension/jars" then
              table.insert(opts.bundles, jar)
            end
          end
        end
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

          -- Auto-download sources/javadoc for every Maven/Eclipse dependency so
          -- jumping into jars (Ctrl-]) shows real source instead of decompiled
          -- bytecode. Slows first-open of a new module by 10-30s but pays off
          -- every time afterwards.
          maven   = { downloadSources = true },
          eclipse = { downloadSources = true },

          -- Keep references on real source/index data only. jdtls can throw in
          -- searchDecompiledSources for some class files, which breaks usages.
          references = { includeDecompiledSources = false },

          -- `symbol-usage.nvim` already renders IDEA-style "N usages" above
          -- declarations. jdtls CodeLens renders the same counts as
          -- "N references", so keep the server-side lenses off for Java.
          referencesCodeLens = { enabled = false },
          implementationsCodeLens = { enabled = false },

          -- Import organization order. Matches Google Java Style + this team's
          -- jakarta/spring conventions.
          completion = {
            importOrder = { "java", "javax", "jakarta", "org", "com" },
            favoriteStaticMembers = {
              "org.junit.jupiter.api.Assertions.*",
              "org.junit.jupiter.api.Assumptions.*",
              "org.junit.jupiter.api.DynamicContainer.*",
              "org.junit.jupiter.api.DynamicTest.*",
              "org.mockito.Mockito.*",
              "org.mockito.ArgumentMatchers.*",
              "org.mockito.Answers.*",
              "org.assertj.core.api.Assertions.*",
              "java.util.Objects.requireNonNull",
              "java.util.Objects.requireNonNullElse",
            },
          },

          -- Run organize-imports on save. Removes unused imports & sorts.
          saveActions = {
            organizeImports = true,
          },

          -- Source-action cleanups available via code-action menu (<leader>ca).
          cleanup = {
            actionsOnSave = {
              "qualifyMembers",
              "qualifyStaticMembers",
              "addOverride",
              "addDeprecated",
            },
          },

          -- Don't bug us about mixed file encodings.
          project = { encoding = "ignore" },

          -- Surface compile errors more aggressively during edits.
          errors = { incompleteClasspath = { severity = "warning" } },
        },
      })

      return opts
    end,

    -- Java-specific keymaps. ft-scoped so they only bind in .java buffers.
    -- Namespace summary:
    --   <leader>cx*  → introspection (bytecode / object layout / jshell)
    --   <leader>cr*  → existing refactor namespace (refactoring.nvim, see refactoring.lua)
    --   <leader>j*   → jdtls-specific code transforms (extract / organize)
    --   <leader>th*  → type-hierarchy (super impl)
    keys = {
      -- Bytecode / runtime introspection — invaluable when reading jar internals
      -- (e.g. seeing the actual bytecode of GatewayProperties' generated getters).
      { "<leader>cxb", function() require("jdtls").javap() end,
        desc = "Java: javap (bytecode)", ft = "java" },
      { "<leader>cxj", function() require("jdtls").jshell() end,
        desc = "Java: open JShell (classpath loaded)", ft = "java" },
      { "<leader>cxl", function() require("jdtls").jol() end,
        desc = "Java: jol (object layout)", ft = "java" },

      -- Imports — the saveActions block above already runs on :w, but these
      -- let you trigger manually and inspect the result.
      { "<leader>jo", function() require("jdtls").organize_imports() end,
        desc = "Java: organize imports", ft = "java" },

      -- jdtls extract refactors. These produce semantically-correct Java
      -- (e.g. handles generics & exception throws) — superior to the
      -- treesitter-based extracts from refactoring.nvim for Java files.
      { "<leader>jev", function() require("jdtls").extract_variable() end,
        mode = { "n", "v" }, desc = "Java: extract variable", ft = "java" },
      { "<leader>jec", function() require("jdtls").extract_constant() end,
        mode = { "n", "v" }, desc = "Java: extract constant", ft = "java" },
      { "<leader>jem", function() require("jdtls").extract_method() end,
        mode = "v", desc = "Java: extract method", ft = "java" },

      -- Type hierarchy navigation. "super_implementation" jumps from an
      -- override to the interface/abstract definition it implements — the
      -- exact thing you need to read filter / handler chains in Spring.
      { "<leader>ths", function() require("jdtls").super_implementation() end,
        desc = "Java: super implementation", ft = "java" },

      -- Tests. jdtls has built-in test runners that work without neotest.
      { "<leader>tt", function() require("jdtls").test_class() end,
        desc = "Java: test class", ft = "java" },
      { "<leader>tr", function() require("jdtls").test_nearest_method() end,
        desc = "Java: test nearest method", ft = "java" },
      { "<leader>tp", function() require("jdtls").pick_test() end,
        desc = "Java: pick test to run", ft = "java" },
    },
  },
}
