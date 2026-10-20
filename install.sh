#!/bin/bash
# Job desk installer for macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/Upsstyle/jobdesk-releases/main/install.sh | bash
#
# Installs, without admin rights where possible:
#   1. Job desk.app (latest release of Upsstyle/jobdesk-releases) into /Applications, or ~/Applications
#   2. Node.js 22 into ~/.jobdesk/node, unless Node 22+ is already installed (PDFs need it)
#   3. Claude Code (Anthropic's official installer), unless it is already installed
#   4. Signs Claude Code in to your Claude subscription (opens the browser)
# Then opens Job desk, whose welcome screen asks for your CV and what you look for.
# Nothing in your Documents folder is touched here; the app creates its folder on first run.
#
# Overrides, for testing: JOBDESK_REPO, JOBDESK_APP_DIR, JOBDESK_SKIP_LOGIN=1, JOBDESK_NO_OPEN=1.
set -euo pipefail

# The built apps live in a public releases repo; the code repo can stay private.
REPO="${JOBDESK_REPO:-Upsstyle/jobdesk-releases}"
APP_NAME="Job desk.app"
JD_HOME="$HOME/.jobdesk"

bold() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
die() { printf '\n\033[31mStopped:\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "Job desk runs on macOS only."
case "$(uname -m)" in
  arm64) ARCH=arm64 ;;
  x86_64) ARCH=x64 ;;
  *) die "Unknown processor: $(uname -m)" ;;
esac
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$JD_HOME"

# 1. The app ------------------------------------------------------------------
bold "1/4  Job desk"
if [ -n "${JOBDESK_APP_DIR:-}" ]; then APPS="$JOBDESK_APP_DIR"
elif [ -w /Applications ]; then APPS=/Applications
else APPS="$HOME/Applications"; fi
mkdir -p "$APPS"
URL="https://github.com/$REPO/releases/latest/download/Job-desk-mac-$ARCH.zip"
curl -fL --progress-bar "$URL" -o "$TMP/app.zip" || die "Could not download $URL"
osascript -e 'tell application "Job desk" to quit' >/dev/null 2>&1 || true
pkill -f "$APPS/$APP_NAME/Contents/MacOS/" >/dev/null 2>&1 || true
sleep 1
rm -rf "$APPS/$APP_NAME"
ditto -x -k "$TMP/app.zip" "$APPS"
[ -d "$APPS/$APP_NAME" ] || die "The download did not contain $APP_NAME"
xattr -dr com.apple.quarantine "$APPS/$APP_NAME" 2>/dev/null || true
ok "Installed in $APPS"

# 2. Node.js -------------------------------------------------------------------
bold "2/4  Node.js (for CV and letter PDFs)"
have_node=""
for n in "$JD_HOME/node/bin/node" "$(command -v node 2>/dev/null || true)" /opt/homebrew/bin/node /usr/local/bin/node; do
  [ -n "$n" ] && [ -x "$n" ] || continue
  major="$("$n" -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [ "$major" -ge 22 ]; then have_node="$n"; break; fi
done
if [ -n "$have_node" ]; then ok "Node $("$have_node" -v) found ($have_node)"
else
  base="https://nodejs.org/dist/latest-v22.x"
  curl -fsSL "$base/SHASUMS256.txt" -o "$TMP/sums" || die "Could not reach nodejs.org"
  file="$(grep -oE "node-v22\.[0-9]+\.[0-9]+-darwin-$ARCH\.tar\.gz" "$TMP/sums" | head -1)"
  [ -n "$file" ] || die "No Node 22 build found for darwin-$ARCH"
  curl -fL --progress-bar "$base/$file" -o "$TMP/$file"
  want="$(grep " $file\$" "$TMP/sums" | cut -d' ' -f1)"
  got="$(shasum -a 256 "$TMP/$file" | cut -d' ' -f1)"
  [ "$want" = "$got" ] || die "Node download failed its checksum"
  rm -rf "$JD_HOME/node" && mkdir -p "$JD_HOME/node"
  tar -xzf "$TMP/$file" -C "$JD_HOME/node" --strip-components 1
  ok "Node $("$JD_HOME/node/bin/node" -v) installed in ~/.jobdesk/node"
fi

# 3. Claude Code ---------------------------------------------------------------
bold "3/4  Claude Code"
CLAUDE=""
for c in "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude; do [ -x "$c" ] && { CLAUDE="$c"; break; }; done
if [ -n "$CLAUDE" ]; then ok "Claude Code found ($CLAUDE)"
else
  curl -fsSL https://claude.ai/install.sh | bash || die "The Claude Code installer failed"
  CLAUDE="$HOME/.local/bin/claude"
  [ -x "$CLAUDE" ] || die "Claude Code did not land in ~/.local/bin"
  ok "Claude Code installed"
fi

# 4. Sign in -------------------------------------------------------------------
bold "4/4  Connect your Claude subscription"
logged_in() { "$CLAUDE" auth status --json 2>/dev/null | grep -q '"loggedIn": *true'; }
if logged_in; then ok "Already signed in"
elif [ "${JOBDESK_SKIP_LOGIN:-}" = "1" ]; then warn "Skipped; Job desk's welcome screen can do it later"
else
  echo "  Your browser opens. Sign in with your Claude account and approve."
  "$CLAUDE" auth login --claudeai </dev/tty || true
  if logged_in; then ok "Signed in"; else warn "Not signed in yet; Job desk's welcome screen can do it later"; fi
fi

# Chrome renders the PDFs ------------------------------------------------------
if [ ! -d "/Applications/Google Chrome.app" ] && [ ! -d "/Applications/Chromium.app" ] && [ ! -d "/Applications/Brave Browser.app" ]; then
  warn "Google Chrome is not installed. Job desk drafts CVs and letters without it, but needs it to make the PDFs: https://www.google.com/chrome/"
fi

bold "Done. Opening Job desk."
echo "  It lives in the menu bar (top right). The welcome screen asks for your CV and what you look for."
[ "${JOBDESK_NO_OPEN:-}" = "1" ] || open "$APPS/$APP_NAME"
