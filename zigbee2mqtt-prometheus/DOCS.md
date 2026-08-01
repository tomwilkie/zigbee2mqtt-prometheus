> [!WARNING]
> This is an **unofficial** Zigbee2MQTT build carrying two unmerged upstream PRs:
> [Koenkk/zigbee2mqtt#31645](https://github.com/Koenkk/zigbee2mqtt/pull/31645) (Prometheus exporter)
> and [Koenkk/zigbee-herdsman#1751](https://github.com/Koenkk/zigbee-herdsman/pull/1751) (metrics
> instrumentation). Everything below is the official app's documentation, plus a
> [Prometheus metrics](#prometheus-metrics) section describing what this build adds.

# Pairing

By default the app has `permit_join` set to `false`. To allow devices to join you need to activate this after the app has started. You can now use the [built-in frontend](https://www.zigbee2mqtt.io/information/frontend.html) to achieve this. For details on how to enable the built-in frontent see the next section.

# Enabling the built-in frontend

Enable `ingress` to have the frontend available in your UI: **Settings → Apps → Zigbee2MQTT → Show in sidebar**. You can find more details about the feature on the [Zigbee2MQTT documentation](https://www.zigbee2mqtt.io/information/frontend.html).

# Configuration

## Onboarding

[Onboarding](https://www.zigbee2mqtt.io/guide/getting-started/#onboarding) allows you to setup Zigbee2MQTT without having to manually enter the details in the app configuration page. When starting the app with a brand new install (no configuration present), the frontend will show a quick setup page, allowing you to select various settings for Zigbee2MQTT to be able to start.

> [!NOTE]
> Successful detection of adapters, to select from, may vary based on your setup/network. You may have to enter these [details manually](https://www.zigbee2mqtt.io/guide/configuration/adapter-settings.html#basic-configuration) on the page instead.

> [!TIP]
> You can force the onboarding to re-run (e.g. changing adapter) using the toggle available in the app configuration page (visible after checking `Show unused optional configuration options`). This will force onboarding to run even after you have successfully configured it for the first time. Make sure to disable it once done.

## Manual

Configuration required to startup Zigbee2MQTT is available from the app configuration. The rest of the options can be configured via the Zigbee2MQTT frontend.

> [!CAUTION]
> Settings configured through the app configuration page will take precedence over settings in the `configuration.yaml` page (e.g. you set `rtscts: false` in app configuration page and `rtscts: true` in `configuration.yaml`, `rtscts: false` will be used). _If you want to control the entire configuration through YAML, remove them from the app configuration page._

#### Examples for each configuration section

- socat
  ```yaml
  enabled: false
  master: pty,raw,echo=0,link=/tmp/ttyZ2M,mode=777
  slave: tcp-listen:8485,keepalive,nodelay,reuseaddr,keepidle=1,keepintvl=1,keepcnt=5
  options: "-d -d"
  log: false
  ```
- mqtt
  ```yaml
  server: mqtt://localhost:1883
  user: my_user
  password: "my_password"
  ```
- serial
  ```yaml
  adapter: zstack
  port: /dev/serial/by-id/usb-Texas_Instruments_TI_CC2531_USB_CDC___0X00124B0018ED3DDF-if00
  ```

# Configuration backup

The app will create a backup of your configuration.yml within your data path: `$DATA_PATH/configuration.yaml.bk`. When upgrading, you should use this to fill in the relevant values into your new config, particularly the network key, to avoid breaking your network and having to re-pair all of your devices.
The backup of your configuration is created on app startup if no previous backup was found.

# Prometheus metrics

This build adds a Prometheus exporter that serves metrics over HTTP. It is **enabled by default**.

## Configuring

The exporter is an app configuration option, alongside `mqtt` and `serial`:

```yaml
prometheus_exporter:
  enabled: true
  port: 9142
  # host: 0.0.0.0   # optional; omit to listen on all interfaces
```

The app writes these into Zigbee2MQTT's own `configuration.yaml` on start, so you can equally set
them there directly (inside your `data_path`, e.g.
`/config/zigbee2mqtt-prometheus/configuration.yaml`), or from the Zigbee2MQTT frontend's settings
page — but the app configuration wins, since it is re-applied every start.

Metrics are served at `http://<ha-host>:9142/metrics` — port `9142/tcp` is published by the app,
so scrape it from anywhere on your network:

```yaml
scrape_configs:
  - job_name: zigbee2mqtt
    static_configs:
      - targets: ["<ha-host>:9142"]
```

## Exported metrics

Device-level series are keyed by `ieee_address`. The friendly name is deliberately exposed only on
`zigbee2mqtt_device_info`, so renaming a device doesn't break the continuity of its other series —
join it in with `on (ieee_address) group_left(friendly_name)`.

| Metric | Type | Labels |
| --- | --- | --- |
| `zigbee2mqtt_build_info` | gauge | `version`, `commit_hash` |
| `zigbee2mqtt_coordinator_info` | gauge | `channel`, `pan_id`, `extended_pan_id`, `coordinator_type`, `revision` |
| `zigbee2mqtt_device_info` | gauge | `ieee_address`, `friendly_name`, `model_id`, `vendor`, `type`, `power_source` |
| `zigbee2mqtt_device_link_quality` | gauge | `ieee_address` |
| `zigbee2mqtt_device_availability` | gauge | `ieee_address` |
| `zigbee2mqtt_device_last_seen_timestamp_seconds` | gauge | `ieee_address` |
| `zigbee2mqtt_device_messages_received_total` | counter | `ieee_address` |
| `zigbee2mqtt_device_messages_sent_total` | counter | `ieee_address` |
| `zigbee2mqtt_device_messages_failed_total` | counter | `ieee_address`, `reason` |
| `zigbee2mqtt_device_joins_total` | counter | `ieee_address` |
| `zigbee2mqtt_device_leaves_total` | counter | `ieee_address` |
| `zigbee2mqtt_device_announces_total` | counter | `ieee_address` |
| `zigbee2mqtt_device_network_address_changes_total` | counter | `ieee_address` |
| `zigbee2mqtt_adapter_send_duration_seconds` | histogram | `type`, `status` |
| `zigbee2mqtt_adapter_retries_total` | counter | `adapter_type`, `reason` |
| `zigbee2mqtt_adapter_receive_zcl_payload_total` | counter | `cluster_id`, `was_broadcast` |
| `zigbee2mqtt_adapter_receive_zdo_response_total` | counter | `cluster_id` |
| `zigbee2mqtt_request_queue_length` | gauge | `ieee_address`, `endpoint_id` |
| `zigbee2mqtt_mqtt_connected` | gauge | — |
| `zigbee2mqtt_mqtt_messages_published_total` | counter | — |
| `zigbee2mqtt_mqtt_messages_received_total` | counter | — |
| `zigbee2mqtt_permit_join` | gauge | — |

Default `prom-client` process/Node.js metrics are exported alongside these.

# Running alongside another Zigbee2MQTT

This app defaults to `data_path: /config/zigbee2mqtt-prometheus`, separate from the official app's
`/config/zigbee2mqtt`, so installing it cannot corrupt an existing setup. To trial it against your
real network, stop the official app first and copy its data directory across — only one app may
own the USB coordinator at a time, and only one may bind host port 9142:

```sh
cp -a /config/zigbee2mqtt /config/zigbee2mqtt-prometheus
```

# Migrating an existing Zigbee2MQTT to this app

Two properties make this safe, and both are worth knowing before you start:

- **Installing from this repository is a side-by-side install, not an upgrade.** The Supervisor
  keys apps by `<repository>_<slug>`, so this app arrives as `<hash>_zigbee2mqtt_prometheus`
  and whatever you were running before stays installed, configured and startable. That is the
  rollback.
- **Zigbee2MQTT keeps no state in the app's own volume** — the database, `coordinator_backup.json`
  and `configuration.yaml` all live under `data_path` in `/config`. So uninstalling the old app
  never destroys your network, and two apps pointed at the same `data_path` hand state over
  between them cleanly, as long as they never run at once.

1. **Back up, twice.** A Supervisor backup for the general case, and a plain copy of the data
   directory, which is what the rollback below actually uses. Take the copy with the app
   **stopped** so the SQLite database is quiesced:

   ```sh
   ha backups new --name pre-prometheus-migration --folders homeassistant --app <oldapp>
   ha apps stop <oldapp>
   cp -a /config/zigbee2mqtt /config/zigbee2mqtt.bak-$(date +%F)
   ```

   `configuration.yaml` holds the network key — this copy is what stands between you and
   re-pairing every device.

2. **Stop the old app from coming back.** Turn off *Start on boot* and *Watchdog* on it, or a
   reboot will have two apps racing for the coordinator. In the UI that's the toggles on its
   Info tab.

3. **Install this app** and set `data_path` to the directory you just backed up, plus whatever
   `mqtt`/`serial` options the old app had — copy them from its Configuration tab. If the old app
   left those empty and kept everything in `configuration.yaml`, leave them empty here too.

4. **Start it and check the log.** Expect `Starting Zigbee2MQTT version <version>`, the adapter
   matching, and `zigbee-herdsman started (resumed)` — *resumed*, not a fresh network form.

5. **Turn on *Start on boot* and *Watchdog*** once you are happy, since you turned them off on the
   old app in step 2.

## Verifying the migration

The exporter gives you a precise before/after. Capture `/metrics` from the old app before you
stop it, and compare:

```sh
curl -s http://<ha-host>:9142/metrics > before.txt   # while the old app still runs
# ... migrate ...
curl -s http://<ha-host>:9142/metrics > after.txt

grep '^zigbee2mqtt_coordinator_info' before.txt after.txt   # must be the same network
diff <(grep -o 'ieee_address="[^"]*"' before.txt | sort -u) \
     <(grep -o 'ieee_address="[^"]*"' after.txt  | sort -u)  # must be empty
```

`zigbee2mqtt_coordinator_info` carrying the same `extended_pan_id` and `channel` is the
confirmation that you resumed the existing network rather than forming a new one, and an empty
device diff means nothing was lost. `zigbee2mqtt_build_info` shows the version you moved to.

## Rolling back

In increasing order of severity:

1. **To the previous app** — the expected path, and a matter of seconds:

   ```sh
   ha apps stop <newapp>
   rm -rf /config/zigbee2mqtt && cp -a /config/zigbee2mqtt.bak-<date> /config/zigbee2mqtt
   ha apps start <oldapp>
   ```

   Restoring the directory is what undoes any settings migration the newer Zigbee2MQTT performed.

2. **To the official app**, giving up metrics but getting Zigbee back. Point it at the data
   directory and start it. The `prometheus_exporter:` block left in `configuration.yaml` is
   harmless there — Zigbee2MQTT's settings schema does not reject unknown keys, so an unforked
   build starts on it unchanged.

3. **Restore the Supervisor backup** from step 1, via Settings → System → Backups.

# Enabling the watchdog

To automatically restart Zigbee2MQTT in case of a soft failure (like "adapter disconnected"), the watchdog can be used. It can be enabled by adding the following to the app configuration:

```yaml
watchdog: default
```

This will use the default watchdog retry delays of 1min, 5min, 15min, 30min, 60min. Custom delays are also supported, e.g. `watchdog: 5,10,30` will start Zigbee2MQTT with the watchdog's retry delays of 5min, 10min, 30min. For more information about the watchdog, read the [docs](https://www.zigbee2mqtt.io/guide/installation/15_watchdog.html).

# Adding Support for New Devices

If you are interested in adding support for new devices to Zigbee2MQTT see [How to support new devices](https://www.zigbee2mqtt.io/how_tos/how_to_support_new_devices.html).

# Notes

- Depending on your configuration, the MQTT server config may need to include the port, typically `1883` or `8883` for SSL communications. For example, `mqtt://core-mosquitto:1883` for Home Assistant's Mosquitto app.
- To find out which serial ports you have exposed go to **Supervisor → System → Host system → ⋮ → Hardware**

# Socat

In some cases it is not possible to forward a serial device to the container that zigbee2mqtt runs in. This could be because the device is not physically connected to the machine at all.

Socat can be used to forward a serial device over TCP to zigbee2mqtt. See the [socat man pages](https://linux.die.net/man/1/socat) for more info.

You can configure the socat module within the socat section using the following options:

- `enabled` true/false to enable socat (default: false)
- `master` master or first address used in socat command line (mandatory)
- `slave` slave or second address used in socat command line (mandatory)
- `options` extra options added to the socat command line (optional)
- `log` true/false if to log the socat stdout/stderr to data_path/socat.log (default: false)

**NOTE:** You'll have to change both the `master` and the `slave` options according to your needs. The defaults values will make sure that socat listens on port `8485` and redirects its output to `/dev/ttyZ2M`. The zigbee2mqtt's serial port setting is NOT automatically set and has to be changed accordingly.

# Credits

The app scaffolding and this documentation are derived from the official
[zigbee2mqtt/hassio-zigbee2mqtt](https://github.com/zigbee2mqtt/hassio-zigbee2mqtt) repository
(Apache-2.0).
