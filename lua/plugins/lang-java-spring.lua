-- Spring "navigation" without the Spring Boot Language Server.
--
-- Why not spring-boot.nvim:
--   The vscode-spring-boot LS expects a tight handshake with jdtls (classpath
--   listener via sts.java.addClasspathListener) that doesn't reliably trigger
--   under nvim-jdtls. Result: LS attaches but never indexes.
--
-- Replacement: pure ripgrep-driven pickers. Less "magic" than the LS, but
-- 100% deterministic and project-wide instantly — no indexing, no wait, no
-- classpath gymnastics. For the actual workflows ("show me all endpoints",
-- "show me all beans") this is just as fast in practice.
--
-- Bindings (ft-scoped to java/yaml/properties):
--   <leader>csm   request mappings (@RequestMapping/@GetMapping/...)
--   <leader>csb   beans (@Service/@Component/@Repository/@Configuration/@Bean)
--   <leader>csc   controllers (@RestController/@Controller)
--   <leader>csa   any Spring stereotype annotation
--   <leader>cs?   cheatsheet
return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>csm",
        function()
          Snacks.picker.grep({
            search  = [[@(RequestMapping|GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping)\s*\(]],
            regex   = true,
            live    = false,
            title   = "Spring · @*Mapping",
            ft      = { "java" },
          })
        end,
        desc = "Spring: find request mappings",
        ft   = { "java", "yaml", "jproperties" },
      },
      {
        "<leader>csb",
        function()
          Snacks.picker.grep({
            search  = [[^\s*@(Service|Component|Repository|Configuration|Bean)\b]],
            regex   = true,
            live    = false,
            title   = "Spring · beans",
            ft      = { "java" },
          })
        end,
        desc = "Spring: find beans",
        ft   = { "java", "yaml", "jproperties" },
      },
      {
        "<leader>csc",
        function()
          Snacks.picker.grep({
            search  = [[^\s*@(RestController|Controller)\b]],
            regex   = true,
            live    = false,
            title   = "Spring · controllers",
            ft      = { "java" },
          })
        end,
        desc = "Spring: find controllers",
        ft   = { "java", "yaml", "jproperties" },
      },
      {
        "<leader>csa",
        function()
          Snacks.picker.grep({
            search  = [[^\s*@(RestController|Controller|Service|Component|Repository|Configuration|Bean|ConfigurationProperties|Autowired|RequestMapping|GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping|EventListener|Async|Scheduled|Transactional)\b]],
            regex   = true,
            live    = false,
            title   = "Spring · any stereotype",
            ft      = { "java" },
          })
        end,
        desc = "Spring: find any annotation",
        ft   = { "java", "yaml", "jproperties" },
      },
      {
        "<leader>csp",
        function()
          -- Find which @ConfigurationProperties class binds a given yaml key
          -- prefix. The mapping lives inside every starter jar at
          -- META-INF/spring-configuration-metadata.json — this is the data
          -- source the official IDE plugins use for completion/hover.
          --
          -- Strategy: scan every ~/.m2 jar in parallel with unzip -p, grep for
          -- the prefix, then fully parse only the matching jars.
          local default = vim.fn.expand("<cWORD>"):match("[%w%.%-_]+") or ""
          vim.ui.input({ prompt = "Spring property prefix: ", default = default }, function(prefix)
            if not prefix or prefix == "" then return end
            local safe_prefix = prefix:gsub("'", "")

            -- Phase 1: find jars whose metadata mentions the prefix.
            vim.notify("Scanning ~/.m2 jars… (5-20s)", vim.log.levels.INFO, { title = "Spring lookup" })
            local scan_cmd = string.format([[
              find %s -name "*.jar" -print0 2>/dev/null | \
              xargs -0 -P 8 -I@ sh -c '
                unzip -p "$1" META-INF/spring-configuration-metadata.json 2>/dev/null | \
                  grep -q "\"name\": *\"%s" && echo "$1"
              ' _ @
            ]], vim.fn.expand("~/.m2/repository"), safe_prefix)

            local matching_jars = vim.fn.systemlist(scan_cmd)
            if #matching_jars == 0 then
              vim.notify("No jar's metadata matches '" .. prefix .. "'", vim.log.levels.WARN)
              return
            end

            -- Phase 2: parse matching jars' metadata fully, collect rows.
            local rows = {}
            for _, jar in ipairs(matching_jars) do
              local json = vim.fn.system(string.format(
                "unzip -p '%s' META-INF/spring-configuration-metadata.json 2>/dev/null",
                jar:gsub("'", "")
              ))
              local ok, data = pcall(vim.fn.json_decode, json)
              if ok and data and data.properties then
                local jar_short = jar:match("repository/(.+)%.jar$") or jar
                for _, prop in ipairs(data.properties) do
                  if prop.name and prop.name:find(prefix, 1, true) then
                    table.insert(rows, {
                      text       = string.format("%-50s  ← %s",
                        prop.name, prop.sourceType or "(?)"),
                      jar        = jar_short,
                      sourceType = prop.sourceType,
                      key        = prop.name,
                    })
                  end
                end
              end
            end

            if #rows == 0 then
              vim.notify("No @ConfigurationProperties matches '" .. prefix .. "'", vim.log.levels.WARN)
              return
            end

            -- Show picker; <CR> jumps via jdtls workspace symbol.
            Snacks.picker.pick({
              source = "static",
              items  = vim.tbl_map(function(r)
                return {
                  text       = r.text,
                  sourceType = r.sourceType,
                  key        = r.key,
                  jar        = r.jar,
                  -- snacks renders a `preview` table with { text = "...", ft = "..." }
                  preview    = {
                    text = table.concat({
                      "yaml key:",
                      "  " .. r.key,
                      "",
                      "Binds to @ConfigurationProperties class:",
                      "  " .. (r.sourceType or "(unknown)"),
                      "",
                      "From jar:",
                      "  " .. r.jar,
                      "",
                      "Press <CR> to jump to the class.",
                    }, "\n"),
                    ft = "text",
                  },
                }
              end, rows),
              format = function(item) return { { item.text } } end,
              -- Tell snacks to render each item's own `preview` table instead
              -- of trying to open item.file (default behaviour → "no file" error).
              preview = "preview",
              title   = string.format("yaml '%s' → @ConfigurationProperties (%d matches in %d jars)",
                prefix, #rows, #matching_jars),
              confirm = function(picker, item)
                picker:close()
                if not item or not item.sourceType then return end
                local class = item.sourceType:match("([^.]+)$")
                vim.schedule(function()
                  vim.lsp.buf.workspace_symbol(class)
                end)
              end,
            })
          end)
        end,
        desc = "Spring: which @ConfigurationProperties binds this yaml prefix?",
        ft   = { "java", "yaml", "jproperties" },
      },
      {
        "<leader>cs?",
        function()
          vim.notify(table.concat({
            "Spring navigation (ripgrep-based)",
            "",
            "  <leader>csm   @RequestMapping / @GetMapping / @PostMapping / ...",
            "  <leader>csb   @Service / @Component / @Repository / @Configuration / @Bean",
            "  <leader>csc   @RestController / @Controller",
            "  <leader>csa   any Spring stereotype",
            "  <leader>csp   yaml key → which @ConfigurationProperties class",
            "  <leader>che   Spring entry → downstream call hierarchy",
            "  <leader>chd   method → boxed ASCII call diagram",
            "  E in graph    current chain → AI call audit panel",
            "",
            "Standard LSP (via jdtls) still handles:",
            "  K          hover (jump from @Autowired to bean impl)",
            "  gd         goto definition (works across modules)",
            "  gi         goto implementation",
            "  gr         find references",
            "  <leader>ss buffer symbols",
            "  <leader>sS workspace symbols (any class name)",
            "  <leader>ca code actions",
            "",
            "For yaml/properties config introspection use actuator:",
            "  Open .http/actuator.http, <leader>Rs to fire",
          }, "\n"), vim.log.levels.INFO, { title = "Spring keymaps" })
        end,
        desc = "Spring: cheatsheet",
        ft   = { "java", "yaml", "jproperties" },
      },
    },
  },
}
