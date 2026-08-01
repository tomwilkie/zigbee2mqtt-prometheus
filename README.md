# Zigbee2MQTT with Prometheus metrics

A Home Assistant add-on repository publishing a build of [Zigbee2MQTT](https://www.zigbee2mqtt.io/)
that exports Prometheus metrics about your Zigbee network.

The metrics support comes from two pull requests that are **open upstream but not merged**:

| PR | What it does | Fork branch |
| --- | --- | --- |
| [Koenkk/zigbee2mqtt#31645](https://github.com/Koenkk/zigbee2mqtt/pull/31645) | Prometheus exporter extension serving `/metrics` | [`tomwilkie/zigbee2mqtt@prometheus-extension`](https://github.com/tomwilkie/zigbee2mqtt/tree/prometheus-extension) |
| [Koenkk/zigbee-herdsman#1751](https://github.com/Koenkk/zigbee-herdsman/pull/1751) | Metrics instrumentation via a typed `EventEmitter`, which the exporter consumes | [`tomwilkie/zigbee-herdsman@metrics-instrumentation`](https://github.com/tomwilkie/zigbee-herdsman/tree/metrics-instrumentation) |

This repo exists to run those branches until (or unless) they land upstream: it holds the add-on
definition, the image build, and the runbook for rebasing the forks onto each new Zigbee2MQTT
release. If the PRs merge, all of this goes away in favour of the official add-on.

Currently built from **Zigbee2MQTT 2.13.0** / **zigbee-herdsman v10.8.0**.

## Installing in Home Assistant

1. **Settings → Add-ons → Add-on store → ⋮ → Repositories**, add
   `https://github.com/tomwilkie/zigbee2mqtt-prometheus`.
2. Install **Zigbee2MQTT (Prometheus)**.
3. It defaults to `data_path: /config/zigbee2mqtt-prometheus`, separate from the official add-on's
   `/config/zigbee2mqtt`, so installing it can't disturb an existing setup. To run it against your
   real network, stop the official add-on and copy its data directory across — only one add-on may
   own the USB coordinator at a time.
4. Enable the exporter in that data directory's `configuration.yaml`:

   ```yaml
   prometheus_exporter:
     enabled: true
     port: 9142
   ```

Metrics are then at `http://<ha-host>:9142/metrics`. See
[the add-on docs](zigbee2mqtt-prometheus/DOCS.md) for the full metric list and rollback steps.

## Repository layout

```
repository.json              Home Assistant add-on repository manifest
zigbee2mqtt-prometheus/      the add-on: config.json, DOCS.md, CHANGELOG.md, icons
build/                       Dockerfile for the image + a local dev stack (compose)
scripts/                     rebase.sh, build-push.sh
src/                         fork checkouts (gitignored, created by scripts/rebase.sh)
```

## Runbook: moving to a new Zigbee2MQTT release

1. **Check what's out.** The zigbee-herdsman version to target is whichever one the Zigbee2MQTT
   release pins, so read it out of that release rather than taking herdsman's latest:

   ```sh
   gh release list --repo Koenkk/zigbee2mqtt --limit 3
   gh api "repos/Koenkk/zigbee2mqtt/contents/package.json?ref=<z2m-tag>" \
       -H "Accept: application/vnd.github.raw" | jq -r '.dependencies["zigbee-herdsman"]'
   ```

2. **Rebase both forks** onto those tags, run their test suites, and force-push:

   ```sh
   scripts/rebase.sh                  # latest stable of each
   scripts/rebase.sh 2.13.0 v10.8.0   # or pin explicitly
   ```

   The script clones the forks into `src/` on first run. zigbee2mqtt's `package.json` pins
   zigbee-herdsman **by commit** (`github:tomwilkie/zigbee-herdsman#<sha>`), not by branch, so
   image builds are reproducible; the script rewrites that pin and the lockfile after rebasing
   herdsman. If a rebase conflicts it stops and leaves the checkout mid-rebase for you to resolve.

3. **Build and push the image** (amd64 only):

   ```sh
   scripts/build-push.sh              # tags <z2m-version>-<short-sha>
   ```

4. **Publish the add-on update**: bump `version` in
   [`zigbee2mqtt-prometheus/config.json`](zigbee2mqtt-prometheus/config.json) to the new tag, add a
   `CHANGELOG.md` entry, commit and push. Home Assistant picks the update up (**⋮ → Check for
   updates** to refresh sooner).

5. **Confirm the PRs are still clean** — the rebase should restore mergeability:

   ```sh
   gh pr view 31645 --repo Koenkk/zigbee2mqtt --json mergeable
   gh pr view 1751 --repo Koenkk/zigbee-herdsman --json mergeable
   ```

### Checking an image before deploying to Home Assistant

Zigbee2MQTT **exits** if it can't open the coordinator's serial port, and extensions (the exporter
included) only start once zigbee-herdsman has — so there is no useful hardware-free end-to-end test
of `/metrics`. What you can check without a coordinator is that the image carries the right code:

```sh
docker run --rm --platform linux/amd64 --entrypoint node \
    tomwilkie/zigbee2mqtt-prometheus-amd64:<tag> -e '
const p = require("/app/package.json");
console.log("z2m", p.version, "| herdsman pin", p.dependencies["zigbee-herdsman"]);
console.log("herdsman metrics API:", Object.keys(require("/app/node_modules/zigbee-herdsman").MetricType).length, "metric types");
console.log("prom-client", require("/app/node_modules/prom-client/package.json").version);
console.log("exporter:", typeof require("/app/dist/extension/prometheusExporter.js"));
'
```

The exporter's own behaviour is covered by `test/extensions/prometheusExporter.test.ts` in the
fork, which `scripts/rebase.sh` runs.

With a coordinator to hand you can run the full stack locally — pass the device through in
`build/docker-compose.yml` first:

```sh
Z2M_TAG=<tag> docker compose -f build/docker-compose.yml --profile image up
curl -s localhost:9142/metrics | grep zigbee2mqtt_build_info
```

Prometheus (`localhost:9090`) and Grafana (`localhost:3000`) in the same stack scrape it.

### Notes on the image build

`build/Dockerfile` derives from the official **stable** add-on image for the same Zigbee2MQTT
release the fork is rebased onto — `ghcr.io/zigbee2mqtt/zigbee2mqtt-amd64:<version>-<rev>`, e.g.
`2.13.0-1` — reusing its HA wrapper, OS and Node, and overlays a locally built `dist/` plus the
fork's exact production dependency closure. `scripts/build-push.sh` resolves the current add-on
revision for that version from the registry and passes it in as `ADDON_IMAGE`; override the env var
to pin a different base. (Don't use the `:edge` tag: it tracks upstream `dev`, so the wrapper and
Node version would drift under a stable overlay.)

If that base ever stops being suitable, the fallback is to adapt `common/Dockerfile` from
[zigbee2mqtt/hassio-zigbee2mqtt](https://github.com/zigbee2mqtt/hassio-zigbee2mqtt), which builds
from source onto `ghcr.io/home-assistant/{arch}-base` and would mean vendoring its `rootfs` here.

When upstream changes the add-on itself (new config options, docs), re-sync
`zigbee2mqtt-prometheus/config.json` and `DOCS.md` against
[`zigbee2mqtt/config.json`](https://github.com/zigbee2mqtt/hassio-zigbee2mqtt/blob/master/zigbee2mqtt/config.json)
and [`zigbee2mqtt/DOCS.md`](https://github.com/zigbee2mqtt/hassio-zigbee2mqtt/blob/master/zigbee2mqtt/DOCS.md).

## Credits

The add-on scaffolding, documentation and artwork are derived from the official
[zigbee2mqtt/hassio-zigbee2mqtt](https://github.com/zigbee2mqtt/hassio-zigbee2mqtt) repository,
Apache-2.0 licensed — see [LICENSE](LICENSE).

`zigbee2mqtt-prometheus/icon.png` and `logo.png` are that artwork with the Prometheus icon from
[cncf/artwork](https://github.com/cncf/artwork/tree/main/projects/prometheus) badged onto it, to
distinguish this add-on from the official one in the Home Assistant UI. Prometheus and its logo are
trademarks of The Linux Foundation.
