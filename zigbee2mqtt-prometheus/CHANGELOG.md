# Changelog

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

Versions follow the upstream Zigbee2MQTT release this build is based on, suffixed with the short
commit of [tomwilkie/zigbee2mqtt@prometheus-extension](https://github.com/tomwilkie/zigbee2mqtt/tree/prometheus-extension):
`X.Y.Z-<sha>`.

## 2.13.0-dd6a6b19

- Rebased onto Zigbee2MQTT `2.13.0` and zigbee-herdsman `v10.8.0`
  ([tomwilkie/zigbee-herdsman@3bcdc1c3](https://github.com/tomwilkie/zigbee-herdsman/commit/3bcdc1c37d46846fbfee1a157cade264847221df)).
- The herdsman fork is now pinned by commit rather than by branch, so builds are reproducible.
- Add-on configuration moved out of the Zigbee2MQTT fork into
  [tomwilkie/zigbee2mqtt-prometheus](https://github.com/tomwilkie/zigbee2mqtt-prometheus), which is
  now a Home Assistant add-on repository.

## 2.12.1-dev-3bdd159

- Prometheus exporter test builds, published from the fork branch directly.
