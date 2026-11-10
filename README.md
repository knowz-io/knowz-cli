# Knowz CLI

`knowz` is the command-line client for Knowz. Connect to Knowz Cloud, your selfhosted instance or another compatible Knowz endpoint; work with knowledge, vaults, files and agent memory from the terminal; and start a local Knowz on your own machine with `knowz up`. This page describes CLI 0.5.8.

## Requirements

- Docker for `knowz up`, already running: Docker Desktop on macOS or Windows, or Docker Engine with the Compose plugin on Linux.
- Node.js 22 or later, only if you install with npm. The install scripts and native installers bundle Node.js.

## Install

macOS and Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/knowz-io/knowz-cli/main/install.sh | sh
```

This installs into `~/.knowz/cli/<version>` and links `knowz` into `~/.local/bin` (add that to your `PATH` if it is not there). Pin a version with `curl -fsSL https://raw.githubusercontent.com/knowz-io/knowz-cli/main/install.sh | sh -s -- --version 0.5.8`; use `--prefix /absolute/path` for an isolated installation.

Windows (PowerShell 5.1 or 7, x64):

```powershell
irm https://raw.githubusercontent.com/knowz-io/knowz-cli/main/install.ps1 | iex
```

This installs into `%LOCALAPPDATA%\Knowz\cli\<version>` and adds `%LOCALAPPDATA%\Knowz\bin` to your user `PATH`; no administrator rights are needed. Open a new terminal afterwards. Pin a version with `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/knowz-io/knowz-cli/main/install.ps1))) -Version 0.5.8`. Windows on ARM: use npm.

Both scripts select the newest release, download the archive for your platform and refuse to install anything that does not match `SHA256SUMS`.

npm, on any platform with Node.js 22 or later:

```sh
npm install -g @knowzai/cli
```

Check the result with `knowz --version`.

## Start

```sh
knowz up
```

Asks which Knowz you want, then the browser guides configuration, first sign-in and connecting the CLI:

- **Knowz Platform (recommended)** — the full platform on your machine. Your browser opens https://app.knowz.io/link: sign in or create a free Knowz account, approve this device, then start the 7-day free trial or choose Standard or above. Setup waits and continues on its own once your plan is active. Images pull through pull.knowz.io, so no registry token is needed.
- **Knowz Self-Hosted (free, open source)** — no account, license or GitHub membership. Without an AI provider you can store and browse knowledge; AI answers need a configured provider.

Skip the question with `knowz up --edition portable` or `knowz up --edition selfhosted`. Scripts and CI runs (no terminal, `--json` or `--yes`) start Self-Hosted unless `--edition` is given.

`knowz down` stops a runtime and keeps its data.

## Native installers

Native packages include Node.js. These installers are **unsigned for now**: the macOS packages are not notarized and the Windows MSI is not code-signed. The install scripts above avoid both prompts and still verify checksums. If you use an installer directly:

- macOS: right-click the `.pkg` and choose **Open**, then **Open** again; or clear the download quarantine first with `xattr -d com.apple.quarantine knowz-cli-v0.5.8-darwin-arm64.pkg`.
- Windows: when SmartScreen shows "Windows protected your PC", choose **More info**, then **Run anyway**.

| Platform | Download |
| --- | --- |
| Linux x64 | [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-v0.5.8-linux-x64.tar.gz) |
| Linux ARM64 | [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-v0.5.8-linux-arm64.tar.gz) |
| macOS Intel | [Installer](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-v0.5.8-darwin-x64.pkg) · [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-v0.5.8-darwin-x64.tar.gz) |
| macOS Apple Silicon | [Installer](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-v0.5.8-darwin-arm64.pkg) · [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-v0.5.8-darwin-arm64.tar.gz) |
| Windows x64 | [Installer](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-v0.5.8-win32-x64.msi) · [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-v0.5.8-win32-x64.tar.gz) |

## Verify

Every asset is listed in [SHA256SUMS](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/SHA256SUMS). For example, from the download folder:

```sh
grep 'knowz-cli-v0.5.8-darwin-arm64.pkg$' SHA256SUMS | shasum -a 256 -c -   # Linux: sha256sum -c -
```

On Windows, compare `(Get-FileHash .\knowz-cli-v0.5.8-win32-x64.msi -Algorithm SHA256).Hash` with its line in `SHA256SUMS`. [release.json](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/release.json) records exact compatibility, image digests and per-artifact signing status.

## Platform notes

- Self-Hosted images run natively on x64 and ARM64. Portable platform images are linux/amd64; on Apple Silicon, Docker Desktop runs them through emulation, so the first start is slower. ARM64 Linux hosts need QEMU/binfmt emulation for the portable edition.
- Windows needs Docker Desktop with Linux containers on the WSL 2 backend. Windows-containers mode cannot run Knowz.
- Linux needs Docker Engine with the Compose plugin (`docker compose version`).
- Installer checks alone do not certify every Docker Desktop or Podman environment.

## Upgrade and uninstall

To upgrade, rerun the install command: the new version installs beside the old one and the `knowz` launcher moves to it. With npm, run `npm install -g @knowzai/cli@latest`. Make an encrypted backup before an explicit runtime upgrade.

Uninstalling keeps runtime data, credentials and profiles unless you ask to purge a runtime:

- Script install, macOS/Linux: `sh ~/.knowz/cli/<version>/uninstall.sh` (add `--purge --edition selfhosted --name <name>` to destroy that runtime first).
- Script install, Windows: `powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\Knowz\cli\<version>\uninstall.ps1"` (add `-Purge -Edition selfhosted -Name <name>`).
- macOS package: `sudo /usr/local/lib/knowz-cli/uninstall.sh`. Windows MSI: Settings → Apps. npm: `npm uninstall -g @knowzai/cli`.

## Agent skills

Download the [Claude skill](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-SKILL.md) or [Codex skill](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.8/knowz-cli-codex-SKILL.md) for this CLI version. The inventory is generated from the same command manifest as the native and npm packages.

## Editions and source

[Knowz Self-Hosted](https://github.com/knowz-io/knowz-selfhosted-source) is available under Apache-2.0. It provides local knowledge, search, optional AI and MCP using your infrastructure. See its quickstart for setup, password recovery and encrypted backup/restore.

The Knowz Platform edition is proprietary and included with Knowz Standard and above, including the free trial. New acquisition and updates are authorized by your Knowz account's plan; registry credentials alone do not authorize them. Private platform code and repository history are excluded from this channel.

## Reporting issues

[Open an issue](https://github.com/knowz-io/knowz-cli/issues) with your operating system, CLI version and redacted error output. Never attach credentials, license tokens or private environment files.
