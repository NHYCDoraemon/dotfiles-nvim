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
| **IDEA layout** | `edgy.nvim` (left/right/bottom docks) · `bufferline.nvim` (tabs) · `dropbar.nvim` (breadcrumb) · `nvim-treesitter-context` (sticky scope) · `neominimap.nvim` (right minimap) · `outline.nvim` (Structure panel) |
| **IDEA keymap** | Full macOS keymap (`⌘O`/`⌘B`/`⇧F6`/`⌘1-9`/etc.) wired to picker/LSP equivalents — requires terminal that forwards Cmd via Kitty Keyboard Protocol (Ghostty / Wezterm) |
| **Themes** | Catppuccin Mocha (default) · Kanagawa Wave — both with italic keywords/types/methods/comments |
| **Animations** | `mini.animate` · `mini.indentscope` · `noice.nvim` (centered cmdline) · `smear-cursor.nvim` |
| **AI** | none (use terminal-native CLIs like `claude`, `codex`, `aider`, `gh copilot` — battle-tested, no nvim plugin to fight with) |
| **Data tooling** | `vim-dadbod-ui` (DB browser) · `kulala.nvim` (HTTP client) |
| **Git** | `neogit` · `diffview.nvim` · `octo.nvim` (PR review) · `git-conflict.nvim` · `lazygit` |
| **Wiki / Notes** | `obsidian.nvim` (vault at `~/notes`) · `markview.nvim` (in-buffer markdown render) |
| **Completion** | `blink.cmp` (Rust-based, faster than nvim-cmp) · `LuaSnip` · `friendly-snippets` |
| **Debug** | `nvim-dap` + `dap-ui` + `dap-virtual-text` per-language adapters |

---

## Requirements

- **macOS** (Intel or Apple Silicon)
- **Ghostty** terminal (or Wezterm) — installer adds it automatically. Apple Terminal **does not work** (no Cmd-key forwarding, no italic).
- **Java 17 (Temurin)** if you want jdtls — installer warns if missing
- **Node** + **Python 3** if you use TS / Python — installer warns if missing
- **GitHub CLI (`gh`)** — only needed if you want `octo.nvim` PR review (run `gh auth login`)

---

## Quick keymap reference

### IDEA shortcuts (work in Ghostty / Wezterm)

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
| `<Space>ff` / `<Space>fg` | Find files / Find text |
| `<Space>nn` / `<Space>nd` | New note / Daily note (Obsidian) |
| `<Space>nn` | New note (Obsidian) |

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
