# Changelog

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
