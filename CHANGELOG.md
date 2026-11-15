# Changelog

## [2.2.0](https://github.com/cameronsjo/obsidi-headless/compare/v2.1.1...v2.2.0) (2026-11-15)


### Features

* synced stamp on the exact Fully synced line; ctime-preserving ownership preflight ([3310060](https://github.com/cameronsjo/obsidi-headless/commit/33100601b6dc326906cca3ec71af025190d6f64e)), closes [#11](https://github.com/cameronsjo/obsidi-headless/issues/11)
* synced stamp on the exact Fully synced line; hardened, ctime-preserving start ([22d5d2c](https://github.com/cameronsjo/obsidi-headless/commit/22d5d2c62d8041fdf0c3b69557529d1be05b6f52))


### Bug Fixes

* a directory at a marker name does not stop the start ([34d1666](https://github.com/cameronsjo/obsidi-headless/commit/34d166691946f59b30db647d2fc95a95310c8250)), closes [#11](https://github.com/cameronsjo/obsidi-headless/issues/11)
* **docker:** pin the base to node:22.23.5-alpine ([d2f76a9](https://github.com/cameronsjo/obsidi-headless/commit/d2f76a98e01fd4eb9f887cecef5815a52576d317))
* **docker:** pin the base to node:22.23.5-alpine ([306611b](https://github.com/cameronsjo/obsidi-headless/commit/306611b4eb55ec9676a9ab795b4e47ec517c366c))
* root-owned run dir, every per-run file cleared at start, 0600 sync pipe ([9cfb26b](https://github.com/cameronsjo/obsidi-headless/commit/9cfb26b9b7db10fb0715796ed0f04f2ede8efd35)), closes [#11](https://github.com/cameronsjo/obsidi-headless/issues/11)

## [2.1.1](https://github.com/cameronsjo/obsidi-headless/compare/v2.1.0...v2.1.1) (2026-10-20)


### Bug Fixes

* stall watchdog so a hung ob sync restarts the container ([#7](https://github.com/cameronsjo/obsidi-headless/issues/7)) ([31c378d](https://github.com/cameronsjo/obsidi-headless/commit/31c378d220cbe0ddfe59a950d1e61afc5a499070))

## [2.1.0](https://github.com/cameronsjo/obsidi-headless/compare/v2.0.0...v2.1.0) (2026-06-20)


### Features

* add fail-loud preflight, heartbeat supervisor, and improved healthcheck ([#4](https://github.com/cameronsjo/obsidi-headless/issues/4)) ([8d1c1a1](https://github.com/cameronsjo/obsidi-headless/commit/8d1c1a193dd20fd99d9b5fb3d60b2b010cc91dc3))

## [2.0.0](https://github.com/cameronsjo/obsidi-headless/compare/v1.0.0...v2.0.0) (2026-03-23)


### ⚠ BREAKING CHANGES

* vault mounts to /vault (was /config/vaults/default), config mounts to /config (was HOME). Requires re-running ob login and ob sync-setup on first start.

### Features

* license, CI, and third-party notices ([6d3f41b](https://github.com/cameronsjo/obsidi-headless/commit/6d3f41b8bc3585a502b02df81c0a94d02e40be9d))
* migrate from Electron+Xvfb to obsidian-headless npm package ([a92963e](https://github.com/cameronsjo/obsidi-headless/commit/a92963ecf3728bbc6f90c2bf8953bee31b07cf4c))


### Bug Fixes

* **ci:** tag latest on every main push, add multi-platform build ([e9152df](https://github.com/cameronsjo/obsidi-headless/commit/e9152dfbd2d98cf881a39c5c5c48ed8289d999b0))
* set HOME=/config so ob persists credentials ([541e108](https://github.com/cameronsjo/obsidi-headless/commit/541e108b19f79b764d6f695bb82e92a77f6ae0a6))

## 1.0.0 (2026-02-12)


### Features

* add release-please and proper semver tagging ([714a34a](https://github.com/cameronsjo/obsidian-headless/commit/714a34a0d1a6474406764a0a8e07ac35bc7f61f9))
* initial obsidian-headless container ([baf22d4](https://github.com/cameronsjo/obsidian-headless/commit/baf22d4426f0d7eed7a505b17506ec235b7c806b))
