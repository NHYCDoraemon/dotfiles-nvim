#!/usr/bin/env bash
#
# dotfiles-nvim — one-line installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/NHYCDoraemon/dotfiles-nvim/main/install.sh | bash
#
# What it does (idempotent — safe to re-run):
#   1. Installs Homebrew if missing
#   2. Installs system deps via brew (neovim, ripgrep, fd, lazygit, JetBrainsMono Nerd Font, Ghostty)
#   3. Installs Rust toolchain (for rust-analyzer)
#   4. Verifies Node / Python / Java (warns if missing)
#   5. Backs up any existing ~/.config/nvim and clones this repo
#   6. Optionally installs Ghostty config (from repo's ghostty/config.example)
#   7. Runs first :Lazy sync to install plugins
#   8. Installs LSPs / formatters / DAP via Mason
#   9. Downloads Lombok agent jar for jdtls (Java)
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
BREW_FORMULAE=(neovim ripgrep fd lazygit graphviz imagemagick plantuml)
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
if [[ -f "$NVIM_CONFIG/kitty/kitty.conf.example" ]]; then
  if [[ -f "$KITTY_CONFIG/kitty.conf" ]]; then
    info "existing Kitty config found — keeping yours."
    info "  reference: $NVIM_CONFIG/kitty/kitty.conf.example"
  else
    mkdir -p "$KITTY_CONFIG"
    cp "$NVIM_CONFIG/kitty/kitty.conf.example" "$KITTY_CONFIG/kitty.conf"
    ok "Kitty config installed at $KITTY_CONFIG/kitty.conf"
  fi
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
Next steps:

  1. Open ${BOLD}Ghostty${NC} (NOT Apple Terminal — Cmd-keys need Kitty Keyboard Protocol)

  2. Run: ${BOLD}nvim${NC}

  3. From the dashboard, press [f] to find files or [c] to edit config

Optional:

  • Set ${BOLD}\$SILICONFLOW_API_KEY${NC} (or override Avante provider) for AI assist:
        export SILICONFLOW_API_KEY="sk-..."

  • Add custom plugins under: ${BOLD}$NVIM_CONFIG/lua/plugins/${NC}

  • Update later: re-run this installer, or:
        cd $NVIM_CONFIG && git pull

Repo: $REPO_URL
EOF
