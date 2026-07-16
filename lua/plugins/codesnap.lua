-- Beautiful code screenshots: select code → export a polished image to the
-- clipboard or a file.
--   <leader>cp  (visual) → snapshot to clipboard
--   <leader>cP  (visual) → snapshot saved to ~/Pictures/CodeSnap
--
-- Config note: this codesnap version deep-merges opts into a NESTED config —
-- window/background/watermark/code_config live under `snapshot_config`.
--
-- Look: "minimal narrow-margin card" — background a touch lighter (#313244)
-- than the code window (#1e1e2e) so the window reads as a floating card
-- (the old same-color-on-same-color version looked muddy), narrow margins,
-- deep shadow. Code font = Liga Comic Mono, same as the editor (the previous
-- default, CaskaydiaCove, isn't installed here and fell back to ugly rendering).
return {
  {
    "mistricky/codesnap.nvim",
    build = "make build_generator",
    cmd = { "CodeSnap", "CodeSnapSave" },
    keys = {
      -- Use ":" (not "<cmd>") on purpose: codesnap reads the selection from the
      -- '< / '> marks, which only update when visual mode EXITS. "<cmd>" keeps
      -- visual mode active → first use errors "No code is selected", and later
      -- uses silently snapshot the PREVIOUS selection. ":" exits visual first.
      { "<leader>cp", ":CodeSnap<cr>",     mode = "x", silent = true, desc = "Code snapshot → clipboard" },
      { "<leader>cP", ":CodeSnapSave<cr>", mode = "x", silent = true, desc = "Code snapshot → save file" },
    },
    opts = {
      save_path = "~/Pictures/CodeSnap",
      snapshot_config = {
        -- This build's syntax theme is baked into a compiled binary blob
        -- (assets/code_themes/default.themedump), not a plain lookup — most
        -- theme names people guess (monokai, dracula, nord, gruvbox, ...)
        -- error "Cannot find X theme" because they were never dumped in.
        -- Verified by decompiling the actual dump with syntect: only THREE
        -- themes exist in this build — "candy" (default, warm/candy-colored),
        -- "vercel" (clean dark, matches this setup's aesthetic), and
        -- "ysgrifennwr". Swap the string below to try the others.
        theme = "vercel",
        window = {
          mac_window_bar = true,
          margin = { x = 40, y = 40 },                    -- narrow frame (default 82)
          shadow = { radius = 40, color = "#00000070" },  -- deeper, larger shadow → card floats
          border = { width = 1, color = "#ffffff20" },    -- hairline edge
        },
        code_config = {
          font_family = "Liga Comic Mono",                -- match the editor
          breadcrumbs = {
            enable = false,                               -- hide file path/name in the shot
          },
        },
        watermark = { content = "" },                     -- no watermark
        background = {
          -- solid, slightly LIGHTER than the window so the card stands out
          stops = {
            { position = 0, color = "#313244" },
            { position = 1, color = "#313244" },
          },
        },
      },
    },
  },
}
