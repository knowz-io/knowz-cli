#!/bin/sh
set -eu

REPOSITORY=${KNOWZ_INSTALL_REPO:-knowz-io/knowz-cli}
VERSION=${KNOWZ_VERSION:-latest}
PREFIX=
PREFIX_EXPLICIT=false

usage() {
  echo "Usage: install.sh [--version vX.Y.Z] [--prefix /path]" >&2
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

if [ "$VERSION" = latest ]; then
  LATEST_URL=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPOSITORY/releases/latest")
  VERSION=${LATEST_URL##*/}
fi
VERSION=${VERSION#v}
case "$VERSION" in
  ''|*[!0-9A-Za-z.-]*) echo "Invalid version: $VERSION" >&2; exit 2 ;;
esac

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
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/knowz-install.XXXXXX")
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT HUP INT TERM

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
rm -f "$LINK_PATH" "$HOME/.local/share/applications/knowz.desktop"
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
