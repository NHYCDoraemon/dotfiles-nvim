# dotfiles-nvim

```
███╗   ██╗██╗  ██╗██╗   ██╗ ██████╗
████╗  ██║██║  ██║╚██╗ ██╔╝██╔════╝
██╔██╗ ██║███████║ ╚████╔╝ ██║
██║╚██╗██║██╔══██║  ╚██╔╝  ██║
██║ ╚████║██║  ██║   ██║   ╚██████╗
╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝

      H A P P Y    C O D I N G
```

Neovim configuration that mirrors **IntelliJ IDEA 2025.3.4**'s window layout, keymap, and visual polish — built on **LazyVim**, designed for daily polyglot coding in Go / Rust / Java 17 / TypeScript+React / Python.

---

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/NHYCDoraemon/dotfiles-nvim/main/install.sh | bash
```

The script is **idempotent** — safe to re-run. It backs up any existing `~/.config/nvim` before installing.

---

## What you get

| Layer | Stack |
|---|---|
| **Base** | LazyVim · `lazy.nvim` · ~100 plugins |
| **Languages** | Go (`gopls` + `gofumpt` + `delve`) · Rust (`rust-analyzer` + `crates.nvim` + `codelldb`) · Java 17 (`jdtls` + Lombok agent) · TS/React (`vtsls` + `eslint` + `tailwindcss-language-server`) · Python (`basedpyright` + `ruff` + `debugpy`) |
| **IDEA layout** | `edgy.nvim` (left/right/bottom docks) · `bufferline.nvim` (tabs) · `dropbar.nvim` (breadcrumb) · `nvim-treesitter-context` (sticky scope) · `neominimap.nvim` (right minimap) · `outline.nvim` (Structure panel) · `no-neck-pain.nvim` (symmetric centering / zen) |
| **IDEA keymap** | Full macOS keymap (`⌘O`/`⌘B`/`⇧F6`/`⌘1-9`/etc.) wired to picker/LSP equivalents — requires terminal that forwards Cmd via Kitty Keyboard Protocol (Kitty / Ghostty / Wezterm) |
| **Themes** | Catppuccin Mocha (default) · Kanagawa Wave — both with italic keywords/types/methods/comments |
| **Animations** | `mini.animate` · `mini.indentscope` · `noice.nvim` (centered cmdline) · `smear-cursor.nvim` · breathing-blink cursor (terminal) · neovide vibrancy (GUI) |
| **AI** | none (use terminal-native CLIs like `claude`, `codex`, `aider`, `gh copilot` — battle-tested, no nvim plugin to fight with) |
| **Data tooling** | `vim-dadbod-ui` (DB browser) · `kulala.nvim` (HTTP client) |
| **Git** | `neogit` · `diffview.nvim` · `octo.nvim` (PR review) · `git-conflict.nvim` · `lazygit` |
| **Refactoring** | `refactoring.nvim` — IntelliJ-style extract-function/variable/block menu via `<leader>cR` |
| **Wiki / Notes** | `obsidian.nvim` (vault at `~/notes`, with inbox / MoC picker / weekly-review prompt keymaps) |
| **Markdown render** | `markview.nvim` (primary, in-buffer, wide-table aware via `tables.use_virt_lines`) · `glow.nvim` (TUI float preview for table-heavy docs) · `render-markdown.nvim` (scoped to Avante chat only) |
| **Diagrams** | `lang-plantuml` — render `.puml` to PNG (`<leader>mr`) **or** Unicode ASCII inside a float (`<leader>mR`, works over SSH / in Neovide) · `lang-mermaid` |
| **Go extras** | `go-callvis` integration — render module call graph to DOT / SVG / PDF, open in Preview.app, or yank to clipboard for AI (`<leader>cg*` family) |
| **Call hierarchy** | Recursive LSP call-tree + in-editor ASCII business graph for Java/Spring and other LSPs — downstream, incoming, Spring entrypoints, boxed diagram with intent/action/input/output details, Markdown/DOT/PDF/SVG export (`<leader>ch*`) |
| **Completion** | `blink.cmp` (Rust-based, faster than nvim-cmp) · `LuaSnip` · `friendly-snippets` |
| **Debug** | `nvim-dap` + `dap-ui` + `dap-virtual-text` per-language adapters |
| **Shell extras** | `shell/zshrc.snippet` is sourced from `~/.zshrc` and wires up `eza` / `bat` / `fzf` (Ctrl-R / Ctrl-T / Alt-C) / `zoxide` (`z foo`) / `starship` prompt — all guarded behind `command -v`, so missing tools are silently skipped |

---

## Requirements

- **macOS** (Intel or Apple Silicon)
- **Kitty** terminal (primary — `image.nvim` previews work reliably, full Kitty Keyboard Protocol). Ghostty and Wezterm both work too; Apple Terminal **does not** (no Cmd-key forwarding, no italic). Installer adds all three casks.
- **Java 17 (Temurin)** if you want jdtls — installer warns if missing
- **Node** + **Python 3** if you use TS / Python — installer warns if missing
- **GitHub CLI (`gh`)** — only needed if you want `octo.nvim` PR review (run `gh auth login`)
- **Optional shell tools** — installer ships `bat` + `fzf`. For the rest of the snippet (`eza`, `zoxide`, `starship`), `brew install eza zoxide starship` — the snippet auto-detects and skips anything missing.

---

## Quick keymap reference

### IDEA shortcuts (work in Kitty / Ghostty / Wezterm)

| Key | Action |
|---|---|
| `⌘O` / `⌘⇧O` / `⌘⌥O` | Goto Class / File / Symbol |
| `⌘B` / `⌘⌥B` | Definition / Implementation |
| `⌘E` / `⌘⇧E` | Recent Files / Recent Locations |
| `⌘F` / `⌘⇧F` | Find in file / Find in path |
| `⌘⌥L` | Reformat |
| `⌘⌥O` | Organize imports |
| `⌥⏎` | Code Action / Quick Fix |
| `⇧F6` | Rename |
| `⌘1` – `⌘9` | Tool windows (Project / Bookmarks / Find / Run / Debug / Problems / Structure / Database / Git) |
| `⌘K` / `⌘⇧K` | Commit / Push (Neogit) |
| `Double⇧` (`<Space><Space>`) | Search Everywhere |

### Leader-key fallbacks (terminal-agnostic)

| Key | Action |
|---|---|
| `<Space>e` | File explorer |
| `<Space>oo` | Structure (Outline) |
| `<Space>op` | Problems (Trouble) |
| `<Space>or` | Run / Tasks |
| `<Space>od` | Debug UI |
| `<Space>og` | Git (Neogit) |
| `<Space>ot` | Terminal |
| `<Space>z` | Zen Mode |
| `<Space>uN` | NoNeckPain — symmetric horizontal centering (chrome-off zen) |
| `<Space>ff` / `<Space>fg` | Find files / Find text |
| `<Space>fn` | Notification history (relocated from `<Space>n` to free the namespace) |

### Notes / Obsidian (`<Space>n*`)

| Key | Action |
|---|---|
| `<Space>nn` / `<Space>nd` | New note / Daily note |
| `<Space>ny` | Yesterday's daily note |
| `<Space>ni` | Open `~/notes/inbox.md` |
| `<Space>nm` | Pick a MoC (Map of Content) from `~/notes/mocs` |
| `<Space>nR` | Open weekly-review prompt in a vsplit (then `:%y+` and paste into AI chat) |
| `<Space>nt` / `<Space>nl` / `<Space>nb` | Tags · Insert link · Backlinks |
| `<Space>nT` | Toggle checkbox |

### Markdown render

| Key | Action |
|---|---|
| `<Space>mt` / `<Space>me` / `<Space>md` | markview — toggle / enable / disable (raw) |
| `<Space>mg` | Glow TUI preview in float (best for wide tables) |
| `<Space>mT` | render-markdown — toggle (Avante chat only) |

### Diagrams (PlantUML / Mermaid)

| Key | Action |
|---|---|
| `<Space>mr` | PlantUML → PNG, open in Preview.app |
| `<Space>mR` | PlantUML → Unicode ASCII art in float (works over SSH / in Neovide) |

### Go call graph (`<Space>cg*`, requires `go-callvis` + `graphviz`)

| Key | Action |
|---|---|
| `<Space>cgg` / `<Space>cgv` | Render full / focused call graph → Preview.app |
| `<Space>cgo` / `<Space>cgO` | Open latest DOT / SVG in floating buffer |
| `<Space>cgy` / `<Space>cgY` | Yank latest DOT / SVG to clipboard (paste into AI) |
| `<Space>cgT` | Module dependency graph |

### Call hierarchy (`<Space>ch*`, requires LSP callHierarchy support)

| Key | Action |
|---|---|
| `<Space>cho` | Downstream call hierarchy from the method under cursor |
| `<Space>chi` | Incoming callers hierarchy for the method under cursor |
| `<Space>che` | Spring entrypoint picker → in-editor ASCII business graph + downstream tree |
| `<Space>chg` | In-editor ASCII business graph from the method under cursor |
| `<Space>chd` | Boxed ASCII diagram from the method under cursor; boxes wrap at about 60% of editor width |
| `G` in tree | Render the current chain as a compact Neovim ASCII graph with explicit arrows and method summaries |
| `A` in tree/graph | Render the current chain as a boxed ASCII diagram with role colors and intent/action/input/output details |
| `E` in tree/graph | Start the explanation, or reopen the active/background result without rerunning it |
| `E` in explanation | Explicitly restart verification for the current chain |
| `q` in explanation | Hide the panel and keep verification running in the background |
| `Q` in explanation | Hide all three explanation panes without stopping verification |
| `L` in explanation | Toggle the compact process log; agent narration stays hidden by default |
| `S` in tree/graph/explanation | Stop the running AI verification task |
| `C` in tree/graph/explanation | Copy the current AI call explanation |
| `<Space>chx` / `Q` in tree/graph | Close every call hierarchy, ASCII/Diagram, and AI explanation task |
| `<CR>` in explanation evidence | Jump to the referenced source location |
| `[` / `]` in explanation | Move to previous / next evidence item |
| `P` in tree | Render the current chain as PDF/SVG with Graphviz and open the PDF |
| `y` in tree | Copy Markdown chain to clipboard; in the ASCII graph, copy the graph text |
| `Y` in tree | Copy DOT graph to clipboard and write a `/tmp/dora-call-hierarchy-*.dot` file |

The AI explanation is evidence-first: it reads the relevant caller/callee context, reconstructs the actual execution order, and labels correctness as verified, partially verifiable, or unverifiable. It does not perform architecture review, general defect hunting, or unsolicited redesign. Verification can run in the background; the panel shows only stage, elapsed time, and evidence-read counts until Codex delivers its final answer, then Neovim notifies you.

### Editing power tools

| Key | Action |
|---|---|
| `s` | Flash jump (label-based teleport) |
| `S` | Flash treesitter selection |
| `gr` | LSP references (Snacks picker) |
| `gd` | Goto definition (Snacks picker) |
| `gI` | Goto implementation |
| `<F5>` | Debug continue |
| `<F8>` / `<F7>` / `<S-F8>` | Step over / into / out |
| `<Tab>` / `<S-Tab>` | Completion next/prev (when menu visible) |
| `<C-j>` / `<C-k>` | Completion next/prev (vim-style) |
| `<CR>` | Accept completion |

---

## AI workflow — terminal CLIs

This config has **no AI plugin**. Inline AI plugins (Avante / CodeCompanion / etc.) all
have rough edges in 2026 — provider quirks, deadlocked input boxes, nested splits that
throw E36, missing reasoning streams. The pragmatic alternative: use **terminal-native AI
CLIs** in a `:term` split or a separate Kitty/Ghostty pane. They are battle-tested and
work with any provider:

| Tool | Use case |
|---|---|
| **`claude`** ([Claude Code](https://claude.com/claude-code)) | Anthropic's official agentic CLI — code edits, project-aware |
| **`codex`** ([OpenAI Codex CLI](https://github.com/openai/codex)) | OpenAI's official CLI |
| **`aider`** ([aider.chat](https://aider.chat)) | Open source, multi-provider, edits files in repo |
| **`gh copilot`** | GitHub Copilot in CLI |

Inside nvim, drop into a terminal: `:term` (or `<Space>ot` to dock at bottom via edgy).
Run any of the above. Your env vars (`ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / etc.)
need to be in `~/.zshrc`.

---

## Shell extras (`shell/zshrc.snippet`)

The installer appends one line to `~/.zshrc` that sources `shell/zshrc.snippet`. It registers:

- `nvd path/to/file` — open a file in **Neovide** (forked, so the shell stays usable)
- `ls` / `ll` / `la` / `lt` — `eza` aliases (icons, git column, tree)
- `cat` — `bat` with paging off (use `\cat` to bypass)
- `Ctrl-R` / `Ctrl-T` / `Alt-C` — `fzf` history / file / dir pickers (Tokyonight-themed, `bat` previewer)
- `z foo` — `zoxide` jump-to-frecent-dir
- prompt — `starship` (replaces oh-my-zsh's theme)

Each block is gated behind `command -v X >/dev/null`, so a fresh machine without `eza` / `zoxide` / `starship` simply skips those blocks until you `brew install` them. If you need machine-specific secrets, drop them in `shell/.env` — that path is gitignored.

---

## Kitty config (`kitty/kitty.conf`)

The installer symlinks the repo's `kitty/kitty.conf` into `~/.config/kitty/`. Highlights worth knowing about:

- **Catppuccin Mocha palette is inlined** — do **not** run `kitty +kitten themes`, it would silently overwrite the inline section. (`current-theme.conf` is gitignored for the same reason.)
- **Kitty hints** — `⌘⇧E` opens a URL hint, `⌘⇧P` then `F` / `L` / `W` / `H` / `N` grabs path / line / word / git-hash / line-number under labels.
- **`notify_on_cmd_finish unfocused 10.0`** — long-running commands ping you only when the window is unfocused.
- **`listen_on unix:/tmp/mykitty-{kitty_pid}`** — `kitty @ ...` remote-control commands work from any shell.
- **Cursor trail tuned aggressive** — single-character moves leave a visible smear (real particle effects live in Neovide via `<leader>uV`).

---

## Customization

Add custom plugins under `lua/plugins/<your-name>.lua`. The file is auto-loaded on next startup.

To override existing options, return another spec for the same plugin — `lazy.nvim` deep-merges:

```lua
-- lua/plugins/my-overrides.lua
return {
  { "folke/snacks.nvim", opts = { dashboard = { width = 80 } } },
}
```

---

## Updating

Re-run the installer (idempotent), or:

```bash
cd ~/.config/nvim && git pull
nvim --headless "+Lazy! sync" +qa
```

---

## Uninstall

```bash
rm -rf ~/.config/nvim
mv ~/.config/nvim.bak.* ~/.config/nvim   # restore your previous config (if installer backed it up)
rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
```

---

## Credits

Built on top of [LazyVim](https://www.lazyvim.org). Heavy lifting from `folke/snacks.nvim`, `folke/edgy.nvim`, `nvim-mini/mini.nvim` family, `Bekaboo/dropbar.nvim`, `Isrothy/neominimap.nvim`, and `MeanderingProgrammer/render-markdown.nvim`.

Inspired by IntelliJ IDEA's New UI (2023.1+).

---

## License

MIT
