# Changelog

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

Versions follow the upstream Zigbee2MQTT release this build is based on, suffixed with the short
commit of [tomwilkie/zigbee2mqtt@prometheus-extension](https://github.com/tomwilkie/zigbee2mqtt/tree/prometheus-extension):
`X.Y.Z-<sha>`, plus a `-N` add-on revision when the packaging changes without the fork moving.

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
