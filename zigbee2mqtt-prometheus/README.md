# Home Assistant App: Zigbee2MQTT (Prometheus)

[![Docker Pulls](https://img.shields.io/docker/pulls/tomwilkie/zigbee2mqtt-prometheus-amd64.svg?style=flat-square&logo=docker)](https://hub.docker.com/r/tomwilkie/zigbee2mqtt-prometheus-amd64)

> [!WARNING]
> This is an **unofficial** build of Zigbee2MQTT. It carries two pull requests that are open
> upstream but not merged:
>
> - [Koenkk/zigbee2mqtt#31645](https://github.com/Koenkk/zigbee2mqtt/pull/31645) — Prometheus exporter extension
> - [Koenkk/zigbee-herdsman#1751](https://github.com/Koenkk/zigbee-herdsman/pull/1751) — metrics instrumentation
>
> If you don't specifically want Prometheus metrics, use the
> [official app](https://github.com/zigbee2mqtt/hassio-zigbee2mqtt) instead.

Zigbee2MQTT lets you use your Zigbee devices **without** the vendor's bridge or gateway. It
bridges events and allows you to control your Zigbee devices via MQTT.

This build adds an HTTP endpoint serving Prometheus metrics about your Zigbee network — per-device
link quality, availability and message counts, adapter latency and retries, MQTT and coordinator
state. See the Documentation tab for how to enable it and what is exported.

The app defaults to `data_path: /config/zigbee2mqtt-prometheus`, i.e. a **separate** data
directory from the official app's `/config/zigbee2mqtt`, so it can be trialled without touching
an existing installation. Only one app may own the USB coordinator at a time.

### Updating

The app version tracks the upstream Zigbee2MQTT release it is built from, suffixed with the fork
commit: e.g. `2.13.0-dd6a6b19`. Updates appear in the HA UI when a new image is published; use
**⋮ → Check for updates** in the app store to refresh sooner.
