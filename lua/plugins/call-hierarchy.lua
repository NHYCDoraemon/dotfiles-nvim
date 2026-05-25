return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>cho",
        function()
          require("dora.call_hierarchy").open({
            direction = "outgoing",
            title = "Downstream Call Hierarchy",
          })
        end,
        desc = "Call hierarchy: downstream",
        ft = { "java", "go", "rust", "typescript", "javascript", "python", "lua" },
      },
      {
        "<leader>chi",
        function()
          require("dora.call_hierarchy").open({
            direction = "incoming",
            title = "Incoming Call Hierarchy",
          })
        end,
        desc = "Call hierarchy: incoming",
        ft = { "java", "go", "rust", "typescript", "javascript", "python", "lua" },
      },
      {
        "<leader>che",
        function()
          require("dora.call_hierarchy").open_spring_entries()
        end,
        desc = "Call hierarchy: Spring entry downstream",
        ft = { "java" },
      },
      {
        "<leader>chg",
        function()
          require("dora.call_hierarchy").open({
            direction = "outgoing",
            title = "Business Call Graph",
            max_depth = 3,
            max_nodes = 80,
            business_view = true,
            graph_first = "ascii",
          })
        end,
        desc = "Call hierarchy: graph from cursor",
        ft = { "java", "go", "rust", "typescript", "javascript", "python", "lua" },
      },
      {
        "<leader>chd",
        function()
          require("dora.call_hierarchy").open({
            direction = "outgoing",
            title = "Business ASCII Diagram",
            max_depth = 3,
            max_nodes = 80,
            business_view = true,
            graph_first = "diagram",
          })
        end,
        desc = "Call hierarchy: ASCII diagram from cursor",
        ft = { "java", "go", "rust", "typescript", "javascript", "python", "lua" },
      },
      {
        "<leader>chx",
        function()
          require("dora.call_hierarchy").close_all()
        end,
        desc = "Call hierarchy: close all panels",
      },
    },
  },

  {
    "folke/edgy.nvim",
    optional = true,
    opts = function(_, opts)
      opts.right = opts.right or {}
      table.insert(opts.right, {
        title = "Call Hierarchy",
        ft = "call_hierarchy",
        size = { width = 52 },
      })
      return opts
    end,
  },
}
