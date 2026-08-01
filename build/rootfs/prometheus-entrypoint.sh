#!/usr/bin/env bash
#
# Wraps the official add-on entrypoint so the Prometheus exporter can be configured from the Home
# Assistant add-on options page, then hands over to it unchanged.
#
# Everything else — socat, mqtt/serial passthrough, watchdog, onboarding — is the base image's
# /docker-entrypoint.sh doing its normal job.
#
# The official entrypoint only forwards the `mqtt` and `serial` option sections, so we forward
# `prometheus_exporter` ourselves, two ways, because neither alone covers both cases:
#
#   * ZIGBEE2MQTT_CONFIG_* env vars — Zigbee2MQTT applies these when it *writes* settings
#     (lib/util/settings.ts), which includes the initial config that onboarding creates. This is
#     what covers a brand new install.
#   * merging into configuration.yaml — a plain restart of an existing install never writes
#     settings, so the env vars alone would not take effect there.
#
# Options are read straight out of /data/options.json (which Supervisor writes) rather than via
# bashio::config, which queries the Supervisor API: an API hiccup there would look identical to
# "the user turned the exporter off", and it can't be exercised outside Home Assistant.

set -euo pipefail

OPTIONS_FILE=/data/options.json

if [[ -f $OPTIONS_FILE ]]; then
    data_path=$(jq -r '.data_path // "/config/zigbee2mqtt"' "$OPTIONS_FILE")
    exporter=$(jq -c '.prometheus_exporter // {}' "$OPTIONS_FILE")

    echo "[prometheus] options: $exporter"

    # Env vars: picked up whenever Zigbee2MQTT writes settings, notably onboarding's initial write.
    for key in enabled port host; do
        value=$(jq -r --arg k "$key" '.[$k] // empty' <<<"$exporter")
        if [[ -n $value ]]; then
            export "ZIGBEE2MQTT_CONFIG_PROMETHEUS_EXPORTER_${key^^}=$value"
        fi
    done

    # Config file: covers existing installs, which may never write settings on a restart.
    node /etc/prometheus-exporter-config.js "${data_path}/configuration.yaml" "$exporter"
else
    echo "[prometheus] $OPTIONS_FILE not found, leaving Zigbee2MQTT's exporter config alone"
fi

exec /docker-entrypoint.sh "$@"
