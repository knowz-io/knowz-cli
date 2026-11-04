#!/bin/sh
set -eu

REPOSITORY=${KNOWZ_INSTALL_REPO:-knowz-io/knowz-cli}
VERSION=${KNOWZ_VERSION:-latest}
PREFIX=
PREFIX_EXPLICIT=false

usage() {
  echo "Usage: install.sh [--version X.Y.Z] [--prefix /path]  (default: the latest published release)" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      VERSION=$2
      shift 2
      ;;
    --prefix)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      PREFIX=$2
      PREFIX_EXPLICIT=true
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [ -z "$REPOSITORY" ]; then
  echo "Set KNOWZ_INSTALL_REPO to the verified public CLI release repository, or install with: npm i -g @knowzai/cli (Node >=22)." >&2
  exit 2
fi
case "$REPOSITORY" in
  *[!A-Za-z0-9._/-]*|/*|*/|*/*/*) echo "KNOWZ_INSTALL_REPO must be an owner/repository pair." >&2; exit 2 ;;
  */*) ;;
  *) echo "KNOWZ_INSTALL_REPO must be an owner/repository pair." >&2; exit 2 ;;
esac

if [ "$(id -u)" -eq 0 ]; then
  if [ "$PREFIX_EXPLICIT" != true ]; then
    echo "Refusing to install as root without an explicit system --prefix." >&2
    exit 1
  fi
  case "$PREFIX" in
    /usr|/usr/*|/opt|/opt/*) ;;
    *) echo "Root installs require a system prefix under /usr or /opt." >&2; exit 1 ;;
  esac
fi

OS_NAME=$(uname -s)
case "$OS_NAME" in
  Linux) OS=linux ;;
  Darwin) OS=darwin ;;
  *) echo "Unsupported operating system: $OS_NAME" >&2; exit 1 ;;
esac

ARCH_NAME=$(uname -m)
case "$ARCH_NAME" in
  x86_64|amd64) ARCH=x64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $ARCH_NAME" >&2; exit 1 ;;
esac

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/knowz-install.XXXXXX")
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT HUP INT TERM

is_release_version() {
  printf '%s\n' "$1" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
}

# Prints one "tag<TAB>draft<TAB>prerelease" line per release object in a GitHub releases list.
# A small JSON scanner (no jq): only keys of the top-level release objects are read, so asset,
# author and release-note text can never be mistaken for release fields.
release_rows() {
  awk '
    function emit_value(v) {
      if (key == "tag_name") tag = v
      else if (key == "draft") draft = v
      else if (key == "prerelease") pre = v
      after_colon = 0
    }
    function end_literal() {
      if (lit != "") { if (depth == 2 && after_colon) emit_value(lit); lit = "" }
    }
    BEGIN { depth = 0; in_str = 0; esc = 0; after_colon = 0; lit = "" }
    {
      line = $0 "\n"; n = length(line)
      for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (in_str) {
          if (esc) { esc = 0; str = str c }
          else if (c == "\\") { esc = 1; str = str c }
          else if (c == "\"") {
            in_str = 0
            if (depth == 2) { if (after_colon) emit_value(str); else key = str }
          } else str = str c
          continue
        }
        if (c == "\"") { end_literal(); in_str = 1; str = ""; continue }
        if (c == "{" || c == "[") {
          end_literal()
          if (depth == 1 && c == "{") { tag = ""; draft = ""; pre = ""; key = "" }
          after_colon = 0; depth++; continue
        }
        if (c == "}" || c == "]") {
          end_literal()
          if (depth == 2 && c == "}") print tag "\t" draft "\t" pre
          depth--; after_colon = 0; continue
        }
        if (c == ":") { if (depth == 2) after_colon = 1; continue }
        if (c == ",") { end_literal(); if (depth == 2) after_colon = 0; continue }
        if (c ~ /[ \t\r\n]/) { end_literal(); continue }
        lit = lit c
      }
    }
  '
}

# Highest v<semver> tag among non-draft releases. Scope "stable" also requires a release that is
# not flagged prerelease and has no -suffix (the release workflow's stable rule); "any" does not.
pick_release_tag() {
  awk -F '\t' -v scope="$1" '
    $2 == "false" && (scope == "any" || ($3 == "false" && index($1, "-") == 0)) && $1 ~ /^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$/ {
      version = substr($1, 2); suffix = ""
      dash = index(version, "-")
      if (dash > 0) { suffix = substr(version, dash + 1); version = substr(version, 1, dash - 1) }
      split(version, part, ".")
      printf "%012d.%012d.%012d.%s\t%s\n", part[1], part[2], part[3], (suffix == "" ? "~" : "-" suffix), $1
    }
  ' | LC_ALL=C sort | tail -n 1 | cut -f 2
}

resolve_latest_version() {
  RELEASES_JSON="$TMP_DIR/releases.json"
  RESOLVED=
  if curl -fsSL -H 'Accept: application/vnd.github+json' -o "$RELEASES_JSON" \
    "https://api.github.com/repos/$REPOSITORY/releases?per_page=20" 2>/dev/null; then
    release_rows <"$RELEASES_JSON" >"$TMP_DIR/releases.tsv"
    RESOLVED=$(pick_release_tag stable <"$TMP_DIR/releases.tsv")
    [ -n "$RESOLVED" ] || RESOLVED=$(pick_release_tag any <"$TMP_DIR/releases.tsv")
  else
    # API unavailable (for example rate-limited): fall back to the latest-release redirect.
    LATEST_URL=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPOSITORY/releases/latest" 2>/dev/null) || LATEST_URL=
    RESOLVED=${LATEST_URL##*/}
  fi
  if [ -z "$RESOLVED" ] || ! is_release_version "$RESOLVED"; then
    echo "Could not resolve the latest Knowz CLI release from $REPOSITORY. Pass --version X.Y.Z (or set KNOWZ_VERSION), or use npm i -g @knowzai/cli (Node >=22)." >&2
    exit 1
  fi
  VERSION=$RESOLVED
}

if [ "$VERSION" = latest ]; then
  resolve_latest_version
fi
is_release_version "$VERSION" || { echo "Invalid version: $VERSION (expected X.Y.Z or X.Y.Z-suffix)." >&2; exit 2; }
VERSION=${VERSION#v}

if [ "$PREFIX_EXPLICIT" = true ]; then
  case "$PREFIX" in
    /*) ;;
    *) echo "--prefix must be an absolute path." >&2; exit 2 ;;
  esac
  INSTALL_DIR="$PREFIX/lib/knowz-cli/$VERSION"
  LINK_PATH="$PREFIX/bin/knowz"
else
  INSTALL_DIR="$HOME/.knowz/cli/$VERSION"
  LINK_PATH="$HOME/.local/bin/knowz"
fi
CLI_BIN="$INSTALL_DIR/bin/knowz"

if [ -x "$CLI_BIN" ] && [ -L "$LINK_PATH" ] && [ "$(readlink "$LINK_PATH")" = "$CLI_BIN" ]; then
  echo "Knowz CLI $VERSION is already installed."
  exit 0
fi

ASSET="knowz-cli-v$VERSION-$OS-$ARCH.tar.gz"
BASE_URL="https://github.com/$REPOSITORY/releases/download/v$VERSION"

curl -fsSL "$BASE_URL/$ASSET" -o "$TMP_DIR/$ASSET" || {
  echo "CLI $VERSION for $OS/$ARCH is unavailable in the configured public channel. Verify the release, or use npm i -g @knowzai/cli (Node >=22)." >&2
  exit 1
}
curl -fsSL "$BASE_URL/SHA256SUMS" -o "$TMP_DIR/SHA256SUMS"
EXPECTED=$(awk -v asset="$ASSET" '{ name=$2; sub(/^\*/, "", name); if (name == asset) print $1 }' "$TMP_DIR/SHA256SUMS")
[ -n "$EXPECTED" ] || { echo "No checksum published for $ASSET." >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL=$(sha256sum "$TMP_DIR/$ASSET" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL=$(shasum -a 256 "$TMP_DIR/$ASSET" | awk '{print $1}')
else
  echo "A SHA-256 tool (sha256sum or shasum) is required." >&2
  exit 1
fi
[ "$ACTUAL" = "$EXPECTED" ] || { echo "Checksum mismatch for $ASSET; nothing was installed." >&2; exit 1; }

STAGE="$TMP_DIR/stage"
mkdir -p "$STAGE"
tar -xzf "$TMP_DIR/$ASSET" -C "$STAGE" --strip-components=1
[ -x "$STAGE/bin/knowz" ] || { echo "Release archive does not contain bin/knowz." >&2; exit 1; }

cat >"$STAGE/uninstall.sh" <<'UNINSTALL'
#!/bin/sh
set -eu
PURGE=false
case "${1:-}" in
  '') ;;
  --purge) PURGE=true; shift ;;
  *) echo "Usage: $0 [--purge [--edition selfhosted|portable] [--name NAME] [--config-dir DIR]]" >&2; exit 2 ;;
esac
INSTALL_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
KNOWZ_BIN="$INSTALL_DIR/bin/knowz"
LINK_PATH="$HOME/.local/bin/knowz"
[ ! -f "$INSTALL_DIR/.link-path" ] || LINK_PATH=$(cat "$INSTALL_DIR/.link-path")
if [ "$PURGE" = true ]; then
  # Teardown checks success before removing the CLI. Other runtimes/profiles survive.
  "$KNOWZ_BIN" runtime destroy --yes --purge-profile "$@"
else
  echo "Preserving runtime data and credentials. Use --purge to destroy a selected runtime first."
fi
if [ -L "$LINK_PATH" ] && [ "$(readlink "$LINK_PATH")" = "$KNOWZ_BIN" ]; then
  rm -f "$LINK_PATH"
fi
DESKTOP_PATH="$HOME/.local/share/applications/knowz.desktop"
if [ -f "$DESKTOP_PATH" ] && grep -Fqx "Exec=\"$KNOWZ_BIN\" up --ui" "$DESKTOP_PATH"; then
  rm -f "$DESKTOP_PATH"
fi
rm -rf "$INSTALL_DIR"
echo "Knowz CLI removed."
UNINSTALL
chmod 755 "$STAGE/uninstall.sh"

mkdir -p "$(dirname "$INSTALL_DIR")" "$(dirname "$LINK_PATH")"
rm -rf "$INSTALL_DIR"
mv "$STAGE" "$INSTALL_DIR"
printf '%s\n' "$LINK_PATH" > "$INSTALL_DIR/.link-path"
TEMP_LINK="$LINK_PATH.tmp.$$"
rm -f "$TEMP_LINK"
ln -s "$CLI_BIN" "$TEMP_LINK"
mv -f "$TEMP_LINK" "$LINK_PATH"

if [ "$OS" = linux ] && [ "$PREFIX_EXPLICIT" != true ]; then
  DESKTOP_DIR="$HOME/.local/share/applications"
  mkdir -p "$DESKTOP_DIR"
  cat >"$DESKTOP_DIR/knowz.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Knowz
Comment=Start the private local Knowz platform
Exec="$CLI_BIN" up --ui
Icon=utilities-terminal
Terminal=false
Categories=Utility;Development;
StartupNotify=true
DESKTOP
fi

echo "Installed Knowz CLI $VERSION at $INSTALL_DIR"
echo "Launcher: $LINK_PATH"
