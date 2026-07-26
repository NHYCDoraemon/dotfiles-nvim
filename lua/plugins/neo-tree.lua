-- Auto-expand only the path to the CURRENT file, not the whole tree.
--
-- We tried binding "Z" to expand_all_nodes first — neo-tree opens a native
-- uv_fs_event watcher PER expanded directory (fs_watch.lua), so expanding an
-- entire real project (multi-module Maven repo, node_modules, etc.) opens
-- hundreds of directories at once and blows past the process's file
-- descriptor limit: "[Neo-tree ERROR] file_event_callback: EMFILE".
--
-- follow_current_file only expands the directories along the path to the
-- buffer you're actually in — bounded by path depth (a handful of levels),
-- never by project size, so it can't hit the same limit.
-- leave_dirs_open = false collapses stale expansions as you move to a
-- different file, keeping the number of open watchers low at all times.
-- Z = expand_all_subnodes: recursively expand ONLY the folder under the
-- cursor (and everything beneath it), not the whole tree. Unlike
-- expand_all_nodes, this defaults its target to `state.tree:get_node()`
-- (commands.lua) — bounded by that one subtree's size, not the whole
-- project, so it's far less likely to open enough fs_event watchers to hit
-- the EMFILE ceiling. (Still possible if you park the cursor on something
-- huge like node_modules — it's scoped, not risk-free.)
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        follow_current_file = { enabled = true, leave_dirs_open = false },
      },
      window = {
        mappings = {
          ["Z"] = "expand_all_subnodes",
        },
      },
    },
  },
}
