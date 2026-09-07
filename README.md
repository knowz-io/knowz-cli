# Knowz CLI

Connect to Knowz Cloud, your selfhosted instance or another compatible Knowz endpoint. Work with knowledge, vaults, files and agent memory from the terminal, or start guided selfhosted setup with `knowz up`.

## Install the 0.5.0 preview

This preview matches selfhosted 0.16.2. With Node.js 22 or later:

```sh
npm install -g @knowzai/cli@0.5.0
knowz --version
knowz up
```

Start Docker Engine with Compose or Docker Desktop before selfhosted setup. The browser guides configuration, first sign-in and connecting the CLI. Public selfhosted images need no Knowz license or GitHub membership. Without an AI provider, you can store and browse knowledge; AI answers need a configured provider.

## Native downloads

Native packages include Node.js 22.23.2. These are **unsigned preview installers**; macOS packages are not notarized and Windows installers are not signed. They have passed installation, repair/reinstallation and data-preserving uninstall checks on the listed hosts. Trusted stable promotion is pending signing. The npm `latest` channel is unchanged.

| Platform | Download |
| --- | --- |
| Linux x64 | [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-v0.5.0-linux-x64.tar.gz) |
| Linux ARM64 | [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-v0.5.0-linux-arm64.tar.gz) |
| macOS Intel | [Installer](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-v0.5.0-darwin-x64.pkg) · [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-v0.5.0-darwin-x64.tar.gz) |
| macOS Apple Silicon | [Installer](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-v0.5.0-darwin-arm64.pkg) · [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-v0.5.0-darwin-arm64.tar.gz) |
| Windows x64 | [Installer](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-v0.5.0-win32-x64.msi) · [Archive](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-v0.5.0-win32-x64.tar.gz) |

Verify downloads against [SHA256SUMS](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/SHA256SUMS). [Release metadata](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/release.json) records exact compatibility, image digests and per-artifact signing status. Installed runtime recovery is verified on Linux x64 and ARM64 with Docker; installer checks alone do not certify every Docker Desktop or Podman environment.

For Linux/macOS, the checksum-checking script selects your archive and installs it in your account:

```sh
curl -fsSL https://raw.githubusercontent.com/knowz-io/knowz-cli/main/install.sh -o knowz-install.sh
sh knowz-install.sh --version 0.5.0
knowz up
```

Use `--prefix /absolute/path` for an isolated installation. Uninstalling the CLI preserves runtime data and profiles by default; stopping a runtime with `knowz down` also preserves data. Make an encrypted backup before an explicit runtime upgrade.

## Matching agent skills

Download the [Claude skill](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-SKILL.md) or [Codex skill](https://github.com/knowz-io/knowz-cli/releases/download/v0.5.0/knowz-cli-codex-SKILL.md) for this CLI version. The inventory is generated from the same command manifest as the native and npm packages.

## Editions and source

[Knowz Self-Hosted](https://github.com/knowz-io/knowz-selfhosted-source) is available under Apache-2.0. It provides local knowledge, search, optional AI and MCP using your infrastructure. See its quickstart for setup, password recovery and encrypted backup/restore.

The contracted portable Knowz platform is proprietary. New acquisition and updates require a valid commercial artifact grant; registry credentials alone do not authorize them. Private platform code and repository history are excluded from this channel.

Report installation issues with your operating system, CLI version and redacted error output. Never attach credentials, license tokens or private environment files.
