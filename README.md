# Knowz CLI

Use Knowz from the terminal: connect to Knowz Cloud, your selfhosted instance, or another Knowz endpoint, and work with knowledge, vaults, files and agent memory.

## Install

The npm package requires Node.js 22 or later:

```sh
npm install -g @knowzai/cli
knowz --help
knowz up
```

`knowz up` opens local browser setup. Selfhosted runs with Docker Engine and Compose or Docker Desktop; its public images do not require a commercial license.

## Native releases

Verified native candidates are listed in [Releases](https://github.com/knowz-io/knowz-cli/releases). Each candidate includes Linux, macOS and Windows payloads, `SHA256SUMS`, a `release.json` compatibility and signing record, and a generated CLI skill. Select a release explicitly when testing a preview. Unsigned or unnotarized installers remain preview artifacts.

## Editions and source

[Knowz Self-Hosted](https://github.com/knowz-io/knowz-selfhosted-source) is available under Apache-2.0. It provides local knowledge, search, optional AI and MCP using your infrastructure.

The contracted portable Knowz platform is proprietary. Its acquisition and updates require a valid commercial artifact grant; registry credentials alone do not authorize them. Private platform code and repository history are excluded from this distribution channel.

Report CLI installation issues in this repository with your operating system, CLI version and redacted error output. Never attach credentials, license tokens or private environment files.
