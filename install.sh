#!/usr/bin/env bash
#
# dotfiles-nvim — one-line installer
#
# Usage:
#   First install:
#     curl -fsSL https://raw.githubusercontent.com/NHYCDoraemon/dotfiles-nvim/main/install.sh | bash
#
#   Upgrade an existing install (pull repo, sync plugins, reload kitty):
#     ~/.config/nvim/install.sh --upgrade
#
# What it does (idempotent — safe to re-run):
#   1. Installs Homebrew if missing
#   2. Installs system deps via brew (neovim, ripgrep, fd, fzf, bat, eza,
#      starship, zoxide, git-delta, lazygit, Nerd Fonts, kitty/ghostty/neovide)
#   3. Installs Rust toolchain (for rust-analyzer)
#   4. Verifies Node / Python / Java (warns if missing)
#   5. Backs up any existing ~/.config/nvim and clones this repo
#   6. Installs Oh My Zsh + custom plugins (zsh-autosuggestions ghost-text
#      completion, fzf-tab, zsh-syntax-highlighting, zsh-completions, you-should-use)
#   7. Symlinks shell & tool configs from the repo (single source of truth):
#        ~/.zshrc ~/.zprofile ~/.zshenv ~/.config/starship.toml ~/.gitconfig
#        ~/.config/kitty/kitty.conf ; seeds ~/.zshrc.local from template
#   8. Optionally installs Ghostty config (from repo's ghostty/config.example)
#   9. Runs first :Lazy sync to install nvim plugins
#  10. Installs LSPs / formatters / DAP via Mason
#  11. Downloads Lombok agent jar for jdtls (Java)
#
# Secrets are NEVER committed: put API tokens / private functions in
# ~/.zshrc.local (gitignored, seeded from shell/zshrc.local.example) or in
# ~/.config/nvim/shell/.env (gitignored, seeded from shell/.env.example).
#
set -euo pipefail

# ============================================================================
# Output helpers
# ============================================================================
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

step()  { printf "\n${BLUE}${BOLD}==>${NC} ${BOLD}%s${NC}\n" "$*"; }
info()  { printf "    %s\n" "$*"; }
warn()  { printf "${YELLOW}!!${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}✓${NC}  %s\n" "$*"; }
err()   { printf "${RED}✗${NC}  %s\n" "$*" >&2; }

# ============================================================================
# Constants
# ============================================================================
REPO_URL="https://github.com/NHYCDoraemon/dotfiles-nvim"
REPO_RAW="https://raw.githubusercontent.com/NHYCDoraemon/dotfiles-nvim/main"
NVIM_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
GHOSTTY_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
LOMBOK_DIR="$HOME/.local/share/nvim/mason/share/lombok"

# ============================================================================
# Banner
# ============================================================================
cat <<'BANNER'

  ███╗   ██╗██╗  ██╗██╗   ██╗ ██████╗
  ████╗  ██║██║  ██║╚██╗ ██╔╝██╔════╝
  ██╔██╗ ██║███████║ ╚████╔╝ ██║
  ██║╚██╗██║██╔══██║  ╚██╔╝  ██║
  ██║ ╚████║██║  ██║   ██║   ╚██████╗
  ╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝

      Neovim · IntelliJ IDEA-Style Setup

BANNER

# ============================================================================
# Platform check
# ============================================================================
if [[ "$OSTYPE" != "darwin"* ]]; then
  err "This installer currently supports macOS only."
  err "Open an issue at $REPO_URL for Linux support."
  exit 1
fi

# ============================================================================
# Upgrade mode: `./install.sh --upgrade`
# Pulls latest, re-syncs plugins, reloads kitty if running. No brew/Mason re-run.
# ============================================================================
if [[ "${1:-}" == "--upgrade" || "${1:-}" == "-u" ]]; then
  step "Upgrade mode"

  if [[ ! -d "$NVIM_CONFIG/.git" ]]; then
    err "$NVIM_CONFIG is not a git checkout — cannot upgrade. Re-run install.sh fresh."
    exit 1
  fi

  info "git pull --ff-only"
  ( cd "$NVIM_CONFIG" && git pull --ff-only )
  ok "repo up to date"

  # Update oh-my-zsh custom plugins (ghost-text completion etc.)
  ZSH_CUSTOM_PLUGINS="$HOME/.oh-my-zsh/custom/plugins"
  if [[ -d "$ZSH_CUSTOM_PLUGINS" ]]; then
    info "updating zsh plugins"
    for d in "$ZSH_CUSTOM_PLUGINS"/*/; do
      [[ -d "$d/.git" ]] && git -C "$d" pull --ff-only --quiet 2>/dev/null || true
    done
    ok "zsh plugins updated"
  fi

  info "Lazy sync plugins (headless)"
  nvim --headless "+Lazy! sync" +qa 2>&1 | tail -3 || true
  ok "plugins synced"

  # Reload kitty if its main process is running (macOS path).
  KITTY_PID="$(pgrep -f 'kitty.app/Contents/MacOS/kitty$' | head -1 || true)"
  if [[ -n "$KITTY_PID" ]]; then
    kill -SIGUSR1 "$KITTY_PID" && ok "Kitty (pid $KITTY_PID) reloaded via SIGUSR1"
  else
    info "Kitty not running — skip reload"
  fi

  cat <<EOF

${GREEN}${BOLD}✓  Upgrade complete${NC}

  Run ${BOLD}source ~/.zshrc${NC} in any open shell to pick up shell-snippet changes.
  (install.sh runs in a child shell — it cannot source into your parent.)

EOF
  exit 0
fi

# ============================================================================
# 1. Homebrew
# ============================================================================
step "Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "already installed: $(brew --version | head -1)"
else
  info "installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for current session (Apple Silicon)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  ok "Homebrew installed"
fi

# ============================================================================
# 2. Brew packages
# ============================================================================
step "Required packages (formulae)"
BREW_FORMULAE=(
  # Core
  neovim          # editor itself
  ripgrep         # snacks.picker live grep
  fd              # snacks.picker file finder
  fzf             # general-purpose fuzzy finder (also used by fzf-tab zsh plugin)
  bat             # cat with syntax-highlighted previews
  eza             # modern ls replacement (ls/ll/la/lt aliases in zshrc.snippet)
  starship        # cross-shell prompt (config: starship/starship.toml)
  zoxide          # smarter cd (`z foo`)
  git-delta       # syntax-highlighted git diffs (configured in git/gitconfig)

  # Git ecosystem
  lazygit         # <leader>gg TUI
  gh              # octo.nvim PR review needs `gh auth login`

  # Diagram rendering
  graphviz        # `dot` for go-callvis SVG output
  imagemagick     # `magick` for image.nvim conversions
  plantuml        # .puml file rendering (lang-plantuml.lua)

  # JSON formatting (kulala.nvim HTTP client uses jq for response pretty-print)
  jq
)
for pkg in "${BREW_FORMULAE[@]}"; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    ok "$pkg"
  else
    info "installing $pkg..."
    brew install "$pkg"
    ok "$pkg installed"
  fi
done

step "Required packages (casks)"
BREW_CASKS=(
  font-maple-mono-nf
  font-jetbrains-mono-nerd-font
  font-victor-mono-nerd-font
  font-geist-mono-nerd-font
  font-commit-mono-nerd-font
  font-monaspace-nerd-font
  kitty           # primary terminal — image.nvim works reliably here
  ghostty         # alternative; image rendering flaky
  neovide         # GUI nvim option
)
for cask in "${BREW_CASKS[@]}"; do
  if brew list --cask "$cask" >/dev/null 2>&1; then
    ok "$cask"
  else
    info "installing $cask..."
    brew install --cask "$cask" || warn "$cask install reported issues — verify manually if needed"
  fi
done

# Verify the primary nvim font is discoverable by macOS / Kitty / Neovide.
# Cask installs put fonts in ~/Library/Fonts/ which macOS auto-detects, but
# occasionally the system font cache lags. fc-match confirms detection works.
step "Font registration check"
if command -v fc-match >/dev/null 2>&1; then
  for fam in "Maple Mono NF" "JetBrainsMono Nerd Font"; do
    resolved=$(fc-match -f '%{family}' "$fam" 2>/dev/null || true)
    if [[ "$resolved" == *"$fam"* ]] || [[ "$fam" == *"$resolved"* ]]; then
      ok "font registered: $fam"
    else
      warn "font '$fam' not resolving (got '$resolved'). Open Font Book to verify or relog macOS."
    fi
  done
else
  info "fontconfig (fc-match) not installed — skipping font verification."
fi

# ============================================================================
# 3. Rust toolchain (rust-analyzer)
# ============================================================================
step "Rust toolchain"
if command -v rustc >/dev/null 2>&1; then
  ok "$(rustc --version)"
else
  info "installing rustup (required for rust-analyzer)..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env"
  ok "rustup installed"
fi

if command -v rustup >/dev/null 2>&1; then
  rustup component add rust-analyzer rustfmt clippy >/dev/null 2>&1 || true
  ok "rust-analyzer / rustfmt / clippy components ready"
fi

# Persist cargo env in shell rc files (idempotent)
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$rc" ]] && ! grep -q 'cargo/env' "$rc"; then
    {
      echo ''
      echo '# Added by dotfiles-nvim installer — for rust-analyzer & rustfmt'
      echo '. "$HOME/.cargo/env"'
    } >> "$rc"
  fi
done

# ============================================================================
# 4. Optional language toolchains
# ============================================================================
step "Go static-analysis CLIs (call-graph visualization)"
if command -v go >/dev/null 2>&1; then
  # Make sure GOPATH/bin is on PATH so go-installed CLIs are findable
  GOBIN="$(go env GOPATH 2>/dev/null)/bin"
  case ":$PATH:" in
    *":$GOBIN:"*) ;;
    *) export PATH="$GOBIN:$PATH" ;;
  esac

  for tool in "github.com/ofabry/go-callvis@latest" "github.com/loov/goda@latest"; do
    name=$(basename "${tool%@*}")
    if command -v "$name" >/dev/null 2>&1; then
      ok "$name already installed"
    else
      info "installing $name..."
      go install "$tool" || warn "$name install failed (skipping)"
    fi
  done

  # Persist GOPATH/bin in rc files
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$rc" ]] && ! grep -q 'GOPATH.*bin\|go env GOPATH' "$rc"; then
      {
        echo ''
        echo '# Added by dotfiles-nvim installer — for go-callvis / goda'
        echo 'export PATH="$(go env GOPATH)/bin:$PATH"'
      } >> "$rc"
    fi
  done
else
  warn "go not found — skipping go-callvis / goda install. Re-run after installing Go."
fi

step "Mermaid CLI (for .mmd file rendering)"
if command -v mmdc >/dev/null 2>&1; then
  ok "mmdc: $(mmdc --version 2>&1 | head -1)"
elif command -v npm >/dev/null 2>&1; then
  info "installing @mermaid-js/mermaid-cli globally..."
  npm install -g @mermaid-js/mermaid-cli >/dev/null 2>&1 && ok "mmdc installed" \
    || warn "mmdc install failed — install manually: npm install -g @mermaid-js/mermaid-cli"
else
  warn "npm not found; install Node first then re-run for mermaid-cli."
fi

step "Optional language toolchains"
for cmd in node python3; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd: $($cmd --version 2>&1 | head -1)"
  else
    warn "$cmd not found — install if you plan to use that language."
  fi
done

# jdtls (Eclipse JDT Language Server) NEEDS Java 21+ to *run its own JVM*.
# Projects can still compile against Java 17 — that's configured in lang-java.lua
# via the `runtimes` block. So we want BOTH JDKs available:
#   * Java 21 → jdtls process
#   * Java 17 → project compile target (most enterprise codebases)
have_jhome() { /usr/libexec/java_home -v "$1" >/dev/null 2>&1; }
if have_jhome 21; then ok "Java 21: $(/usr/libexec/java_home -v 21)"
else warn "Java 21 missing (required by jdtls). Install: brew install --cask temurin@21"
fi
if have_jhome 17; then ok "Java 17: $(/usr/libexec/java_home -v 17)"
else warn "Java 17 missing (project target). Install: brew install --cask temurin@17"
fi

# ============================================================================
# 5. Clone / update nvim config
# ============================================================================
step "Neovim config"
if [[ -d "$NVIM_CONFIG" ]]; then
  if [[ -d "$NVIM_CONFIG/.git" ]] && git -C "$NVIM_CONFIG" remote get-url origin 2>/dev/null | grep -q "dotfiles-nvim"; then
    info "existing dotfiles-nvim install detected — pulling latest..."
    git -C "$NVIM_CONFIG" pull --ff-only
    ok "updated"
  else
    backup="${NVIM_CONFIG}.bak.$(date +%s)"
    warn "existing nvim config found at $NVIM_CONFIG"
    warn "  backing up to: $backup"
    mv "$NVIM_CONFIG" "$backup"
    git clone "$REPO_URL" "$NVIM_CONFIG"
    ok "cloned to $NVIM_CONFIG"
  fi
else
  git clone "$REPO_URL" "$NVIM_CONFIG"
  ok "cloned to $NVIM_CONFIG"
fi

# Wipe stale plugin/state caches so first sync is clean
for d in "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
  if [[ -d "$d" ]] && [[ ! -f "$d/.dotfiles-nvim-fresh" ]]; then
    backup="${d}.bak.$(date +%s)"
    info "moving stale $d to $backup"
    mv "$d" "$backup"
  fi
done

# ============================================================================
# 6. Terminal configs (Kitty primary, Ghostty optional)
# ============================================================================
step "Kitty config (primary terminal)"
KITTY_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
KITTY_SRC="$NVIM_CONFIG/kitty/kitty.conf"
KITTY_DST="$KITTY_CONFIG/kitty.conf"
if [[ -f "$KITTY_SRC" ]]; then
  mkdir -p "$KITTY_CONFIG"
  # We symlink rather than copy: the repo file is the single source of truth,
  # so `git pull` (or --upgrade) propagates instantly with no copy step.
  if [[ -L "$KITTY_DST" && "$(readlink "$KITTY_DST")" == "$KITTY_SRC" ]]; then
    ok "Kitty config already symlinked → $KITTY_SRC"
  else
    if [[ -e "$KITTY_DST" || -L "$KITTY_DST" ]]; then
      backup="${KITTY_DST}.bak.$(date +%s)"
      mv "$KITTY_DST" "$backup"
      info "backed up existing Kitty config to $backup"
    fi
    ln -s "$KITTY_SRC" "$KITTY_DST"
    ok "Kitty config symlinked: $KITTY_DST → $KITTY_SRC"
  fi
fi

# ----------------------------------------------------------------------------
# Oh My Zsh framework + custom plugins (the inline ghost-text completion,
# fzf-powered Tab menu, syntax highlighting, etc.)
# ----------------------------------------------------------------------------
step "Oh My Zsh framework"
ZSH_DIR="$HOME/.oh-my-zsh"
if [[ -d "$ZSH_DIR" ]]; then
  ok "oh-my-zsh already installed"
else
  info "installing oh-my-zsh (unattended, keeping our own .zshrc)..."
  # RUNZSH=no  → don't drop us into a new shell
  # KEEP_ZSHRC=yes → never touch ~/.zshrc (we symlink our own below)
  RUNZSH=no KEEP_ZSHRC=yes CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  ok "oh-my-zsh installed"
fi

step "Zsh plugins (autosuggestions / fzf-tab / syntax-highlighting / completions)"
ZSH_CUSTOM_PLUGINS="$ZSH_DIR/custom/plugins"
mkdir -p "$ZSH_CUSTOM_PLUGINS"
# name|repo — clone if absent, otherwise pull latest (idempotent).
ZSH_PLUGINS=(
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
  "fzf-tab|https://github.com/Aloxaf/fzf-tab"
  "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting"
  "zsh-completions|https://github.com/zsh-users/zsh-completions"
  "you-should-use|https://github.com/MichaelAquilina/zsh-you-should-use"
)
for entry in "${ZSH_PLUGINS[@]}"; do
  name="${entry%%|*}"; repo="${entry##*|}"
  dest="$ZSH_CUSTOM_PLUGINS/$name"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" pull --ff-only --quiet 2>/dev/null && ok "$name (updated)" || ok "$name (present)"
  else
    info "cloning $name..."
    git clone --depth=1 "$repo" "$dest" >/dev/null 2>&1 && ok "$name cloned" \
      || warn "$name clone failed — check network and re-run"
  fi
done

# ----------------------------------------------------------------------------
# Shell + tool config files — symlinked from the repo (single source of truth;
# `git pull` propagates instantly). Existing files are backed up, not clobbered.
# ----------------------------------------------------------------------------
step "Shell & tool configs (symlinks)"

link_config() {
  # link_config <repo-relative-src> <absolute-dest>
  local src="$NVIM_CONFIG/$1" dst="$2"
  [[ -f "$src" ]] || { warn "missing in repo: $1 (skip)"; return; }
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    ok "$dst → $1 (already linked)"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    local backup="${dst}.bak.$(date +%s)"
    mv "$dst" "$backup"
    info "backed up existing $dst → $backup"
  fi
  ln -s "$src" "$dst"
  ok "$dst → $1"
}

link_config "shell/zshrc"           "$HOME/.zshrc"
link_config "shell/zprofile"        "$HOME/.zprofile"
link_config "shell/zshenv"          "$HOME/.zshenv"
link_config "starship/starship.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
link_config "git/gitconfig"         "$HOME/.gitconfig"

# Seed the private override file (secrets + machine-specific) from its template.
ZSHRC_LOCAL="$HOME/.zshrc.local"
if [[ ! -f "$ZSHRC_LOCAL" && -f "$NVIM_CONFIG/shell/zshrc.local.example" ]]; then
  cp "$NVIM_CONFIG/shell/zshrc.local.example" "$ZSHRC_LOCAL"
  warn "created $ZSHRC_LOCAL from template — add your API tokens / private functions there"
else
  ok "$ZSHRC_LOCAL present (kept)"
fi

# Seed shell/.env from .env.example if absent so users see the template.
ENV_LOCAL="$NVIM_CONFIG/shell/.env"
if [[ ! -f "$ENV_LOCAL" && -f "$NVIM_CONFIG/shell/.env.example" ]]; then
  info "shell/.env not present — copy shell/.env.example and fill in values if you need any secrets"
fi

step "Ghostty config (alternative terminal)"
if [[ -f "$NVIM_CONFIG/ghostty/config.example" ]]; then
  if [[ -f "$GHOSTTY_CONFIG/config" ]]; then
    info "existing Ghostty config found — keeping yours."
    info "  reference: $NVIM_CONFIG/ghostty/config.example"
  else
    mkdir -p "$GHOSTTY_CONFIG"
    cp "$NVIM_CONFIG/ghostty/config.example" "$GHOSTTY_CONFIG/config"
    ok "Ghostty config installed at $GHOSTTY_CONFIG/config"
  fi
fi

# ============================================================================
# 7. First plugin sync
# ============================================================================
step "First :Lazy sync (this can take 1-3 minutes)"
info "fetching ~100 plugins..."
nvim --headless "+Lazy! sync" +qa 2>&1 | tail -3 || true
ok "plugins synced"

# ============================================================================
# 8. Mason — LSPs / formatters / DAP
# ============================================================================
step "Mason tools (LSPs / formatters / debuggers)"
info "installing language servers..."
nvim --headless "+Lazy load mason.nvim" \
  "+MasonInstall gopls rust-analyzer basedpyright vtsls eslint-lsp tailwindcss-language-server prettierd gofumpt goimports google-java-format codelldb delve debugpy js-debug-adapter ruff" \
  +qa 2>&1 | tail -3 || true
ok "Mason tools installed"

# ============================================================================
# 9. Lombok agent (Java jdtls)
# ============================================================================
step "Lombok agent for jdtls (Java)"
mkdir -p "$LOMBOK_DIR"
if [[ ! -f "$LOMBOK_DIR/lombok.jar" ]]; then
  info "downloading lombok.jar..."
  curl -fsSL -o "$LOMBOK_DIR/lombok.jar" https://projectlombok.org/downloads/lombok.jar
  ok "lombok.jar at $LOMBOK_DIR/lombok.jar"
else
  ok "lombok.jar already present"
fi

# ============================================================================
# Done
# ============================================================================
printf "\n${GREEN}${BOLD}✓  Installation complete${NC}\n\n"

cat <<EOF
${BOLD}Three terminals for three use cases:${NC}

  ${BOLD}Kitty${NC}     — primary, image.nvim renders mermaid/PNG inline
  ${BOLD}Neovide${NC}   — GUI nvim, gorgeous fonts/animations (no inline images yet)
  ${BOLD}Ghostty${NC}   — alternate terminal, Cmd-key passthrough

  Open one of them, then run: ${BOLD}nvim${NC}
  From dashboard, press [f] to find files or [c] to edit config.

${BOLD}AI workflow:${NC}

  No nvim AI plugin (intentional — they're flaky in 2026). Use terminal CLIs:
    ${BOLD}claude${NC} (Claude Code) · ${BOLD}codex${NC} (OpenAI) · ${BOLD}aider${NC} · ${BOLD}gh copilot${NC}
  Drop into a terminal split with ${BOLD}:term${NC} or ${BOLD}<Space>ot${NC}.

${BOLD}Java users:${NC}

  jdtls needs Java 21 to RUN, but can target older Java versions.
  If 'java -version' is < 21, install:
    ${BOLD}brew install --cask temurin@21 temurin@17${NC}

${BOLD}Octo (GitHub PR review):${NC}

  ${BOLD}gh auth login${NC}  ← one-time, then <leader>gpl shows PRs.

${BOLD}Useful shortcuts to try right away:${NC}

  ${BOLD}<Space>ff${NC}  Find file        ${BOLD}<Space>fg${NC}  Live grep
  ${BOLD}<Space>e${NC}   File explorer   ${BOLD}<Space>oo${NC}  Structure (Outline)
  ${BOLD}<Space>z${NC}   Zen mode        ${BOLD}<Space>P${NC}   Switch project + session
  ${BOLD}<Space>nn${NC}  New note         ${BOLD}<Space>mp${NC}  Markdown browser preview
  ${BOLD}<Space>st${NC}  TODOs (project) ${BOLD}<Space>uf${NC}  Pick font (Neovide live)

${BOLD}Update later:${NC}

  Re-run this installer (idempotent), or:
    ${BOLD}cd $NVIM_CONFIG && git pull && nvim --headless "+Lazy! sync" +qa${NC}

Repo: ${BOLD}$REPO_URL${NC}
EOF
