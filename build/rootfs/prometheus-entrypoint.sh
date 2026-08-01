#!/usr/bin/env bash
#
# Wraps the official add-on entrypoint so the Prometheus exporter can be configured from the Home
# Assistant add-on options page, then hands over to it unchanged.
#
# Everything else — socat, mqtt/serial passthrough, watchdog, onboarding — is the base image's
# /docker-entrypoint.sh doing its normal job.
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
    node /etc/prometheus-exporter-config.js "${data_path}/configuration.yaml" "$exporter"
else
    echo "[prometheus] $OPTIONS_FILE not found, leaving Zigbee2MQTT's exporter config alone"
fi

exec /docker-entrypoint.sh "$@"
