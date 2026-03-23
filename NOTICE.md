# Third-Party Notices

## obsidian-headless

This project uses [`obsidian-headless`](https://www.npmjs.com/package/obsidian-headless),
an official npm package by [Dynalist Inc.](https://obsidian.md) (the makers of Obsidian).

- **License:** UNLICENSED (proprietary)
- **npm:** <https://www.npmjs.com/package/obsidian-headless>
- **GitHub:** <https://github.com/obsidianmd/obsidian-headless>
- **Requires:** Active [Obsidian Sync](https://obsidian.md/sync) subscription

The `obsidian-headless` package's own license terms apply to its binaries
contained in built Docker images.

## Node.js

The Docker image is based on [`node:22-alpine`](https://hub.docker.com/_/node),
which includes Node.js under the [MIT License](https://github.com/nodejs/node/blob/main/LICENSE)
and Alpine Linux packages under their respective open source licenses.

## Container Utilities

- **tini** — [MIT License](https://github.com/krallin/tini/blob/master/LICENSE)
- **su-exec** — [MIT License](https://github.com/ncopa/su-exec/blob/master/LICENSE)

The PolyForm Noncommercial license in this repository covers only the
Dockerfile, entrypoint script, CI configuration, and documentation — NOT
the obsidian-headless package or Node.js runtime.
