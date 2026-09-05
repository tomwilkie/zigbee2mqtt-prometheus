# Changelog

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

Versions follow the upstream Zigbee2MQTT release this build is based on, suffixed with the short
commit of [tomwilkie/zigbee2mqtt@prometheus-extension](https://github.com/tomwilkie/zigbee2mqtt/tree/prometheus-extension):
`X.Y.Z-<sha>`, plus a `-N` add-on revision when the packaging changes without the fork moving.

## 2.14.1-693372ec

- Zigbee2MQTT 2.13.0 → 2.14.1, and zigbee-herdsman v10.8.0 → v10.9.2 — the version 2.14.1 pins,
  not herdsman's latest release (v10.9.3). 2.14.1 is a hotfix over 2.14.0 correcting inverted
  cover states; neither release adds a `breaking_versions` entry, so this is a normal update.
- Rebasing the exporter needed two fixups, both upstream refactors rather than behaviour changes:
  `Zigbee2MQTTSettings` became a `type` instead of an `interface`, and the `object-assign-deep`
  dependency was dropped. The `prometheus_exporter` settings entry and the `prom-client`
  dependency were re-applied onto those new shapes; the exporter's own code is unchanged and its
  35 tests still pass.
- The image build now compiles native addons with LTO off (`CFLAGS`/`CXXFLAGS`/`LDFLAGS=-fno-lto`
  in `build/Dockerfile`). herdsman v10.9.x patches `@serialport/bindings-cpp` for Node v26.3+
  ([#1856](https://github.com/Koenkk/zigbee-herdsman/pull/1856)), so pnpm stores it under a
  directory named `...patch_hash=<sha>`; the base image's Node is built with `enable_lto`, and
  GCC's lto-wrapper drives its link through a generated makefile that reads the `=` in that path
  as a variable assignment and fails. Only the build changed — the binding still loads and
  enumerates ports in the finished image.
- Re-synced the serial-port discovery instructions in `DOCS.md` from the official add-on, which
  had gone stale: they now point at **Settings → System → Hardware → ⋮ → System hardware**
  ([hassio-zigbee2mqtt@da1992fd](https://github.com/zigbee2mqtt/hassio-zigbee2mqtt/commits/da1992fd25d7a2b12b186509f881f8ea8dc12ec9/zigbee2mqtt/DOCS.md)).
  Upstream's `config.json` moved too, but only its own `version` field, so our copy needed no
  change beyond the version bump.

## 2.13.0-1e1df702-2

- The sidebar icon is now `mdi:zigbee` (was `mdi:chart-line`), matching the official add-on.
  It can't be `logo.png`: `panel_icon` takes an MDI icon name, and the frontend component that
  renders it resolves `prefix:name` against MDI or a registered custom iconset — it has no path to
  rendering an image. `icon.png`/`logo.png` appear on the add-on store card and add-on page only.
- Packaging only. The image is the one published for `2.13.0-1e1df702`, re-tagged rather than
  rebuilt (`docker buildx imagetools create`), so the amd64 manifest digest is unchanged. The
  version bump exists solely because the Supervisor pulls `<image>:<version>` and an installed
  add-on keeps its metadata until it is updated.

## 2.13.0-1e1df702

- No functional change: both fork branches were rewritten to sign their commits, so the
  zigbee-herdsman pin moved to the re-signed commit
  ([244a2b29](https://github.com/tomwilkie/zigbee-herdsman/commit/244a2b294075ee2c0dbe724ec8fe1dbbcc1361ee))
  and the image was rebuilt against it.

## 2.13.0-446c918e

- `prometheus_exporter` is now in Zigbee2MQTT's settings schema (added to
  [#31645](https://github.com/Koenkk/zigbee2mqtt/pull/31645)), so it can be set via
  `ZIGBEE2MQTT_CONFIG_*` env vars and shows up in the Zigbee2MQTT frontend's settings page.
- The add-on forwards its `prometheus_exporter` option through those env vars as well as into
  `configuration.yaml`, so the setting now also applies on a brand new install's first start,
  via the config that onboarding writes.

## 2.13.0-dd6a6b19-2

- The Prometheus exporter is now an add-on option and is **enabled by default**. Previously it
  followed Zigbee2MQTT's default of disabled and could only be turned on by hand-editing
  `configuration.yaml`, since the add-on entrypoint has no way to reach the setting.
- On a brand new install the setting is applied from the second start onwards, so that onboarding
  can create `configuration.yaml` first.

## 2.13.0-dd6a6b19

- Rebased onto Zigbee2MQTT `2.13.0` and zigbee-herdsman `v10.8.0`
  ([tomwilkie/zigbee-herdsman@3bcdc1c3](https://github.com/tomwilkie/zigbee-herdsman/commit/3bcdc1c37d46846fbfee1a157cade264847221df)).
- The herdsman fork is now pinned by commit rather than by branch, so builds are reproducible.
- The image is now built on the official *stable* add-on image for the matching release
  (`ghcr.io/zigbee2mqtt/zigbee2mqtt-amd64:2.13.0-1`) instead of the `:edge` tag, which tracks
  upstream `dev` and so moved the wrapper and Node version under a stable overlay.
- Add-on configuration moved out of the Zigbee2MQTT fork into
  [tomwilkie/zigbee2mqtt-prometheus](https://github.com/tomwilkie/zigbee2mqtt-prometheus), which is
  now a Home Assistant add-on repository.

## 2.12.1-dev-3bdd159

- Prometheus exporter test builds, published from the fork branch directly.
