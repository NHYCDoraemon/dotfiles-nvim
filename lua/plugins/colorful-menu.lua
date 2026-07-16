-- Syntax-highlighted completion items (JetBrains / VSCode style): the completion
-- menu label is colored by token — function names, types, parameters each get
-- their own color instead of one flat foreground. Purely cosmetic, scoped to the
-- blink.cmp menu; nothing else is touched.
return {
  { "xzbdmw/colorful-menu.nvim", opts = {} },
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        menu = {
          draw = {
            columns = { { "kind_icon" }, { "label", gap = 1 } },
            components = {
              label = {
                text = function(ctx)
                  return require("colorful-menu").blink_components_text(ctx)
                end,
                highlight = function(ctx)
                  return require("colorful-menu").blink_components_highlight(ctx)
                end,
              },
            },
          },
        },
      },
    },
  },
}
