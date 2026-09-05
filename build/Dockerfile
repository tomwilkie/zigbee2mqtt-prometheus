# Builds a Home Assistant Zigbee2MQTT addon image carrying the prometheus-extension branch.
#
# Strategy: derive from the official *stable* addon image for the same Zigbee2MQTT release the
# fork is rebased onto, which already provides the HA s6/bashio wrapper, the OS, Node, and
# ABI-compatible native @serialport bindings. A deps stage runs `pnpm install` from the fork's
# lockfile to produce the exact prod dependency closure (incl. prom-client and the
# zigbee-herdsman metrics fork), then the final stage overlays that node_modules plus the
# locally-built dist/ and index.js onto the wrapper.
#
# Both stages share the same base image, so the recompiled @serialport binary is ABI-correct
# for the runtime.
#
# The base tag is <z2m-version>-<addon-revision>, e.g. 2.13.0-1 — immutable, and matched to the
# release we overlay. scripts/build-push.sh resolves the current revision and passes it in; the
# default here is only a fallback. (Earlier builds used the :edge tag, which tracks upstream dev
# and so silently moved the wrapper and Node version under a stable overlay.)
#
# Build context is the zigbee2mqtt checkout (src/zigbee2mqtt), NOT this repo — see
# scripts/build-push.sh. `pnpm run build` must have been run there first so dist/ exists. This
# repo's build/ directory is passed in as the named context `addon`.
#
# If these images ever stop being a suitable base (e.g. Node major diverges from the fork's
# requirements), the fallback is to adapt common/Dockerfile from
# zigbee2mqtt/hassio-zigbee2mqtt, which builds from source onto ghcr.io/home-assistant/{arch}-base
# and would mean vendoring its rootfs (s6 services, entrypoint, healthcheck) here too.

ARG ADDON_IMAGE=ghcr.io/zigbee2mqtt/zigbee2mqtt-amd64:2.13.0-1

# --- deps: compute the fork's exact prod closure (mirrors docker/Dockerfile's deps stage) ---
FROM ${ADDON_IMAGE} AS deps

WORKDIR /build

COPY package.json pnpm-lock.yaml ./

# The base image's Node is built with `enable_lto`, which node-gyp propagates into every native
# addon build, so linking runs through GCC's lto-wrapper. That wrapper drives the parallel link
# with a generated makefile listing object paths — and since zigbee-herdsman v10.9.x patches
# @serialport/bindings-cpp (Koenkk/zigbee-herdsman#1856), pnpm stores it in a directory whose name
# contains `patch_hash=<sha>`. make reads the `=` in that path as a variable assignment and dies
# with "recipe commences before first target". Turning LTO off for the addon build sidesteps it;
# these are appended after gyp's own flags, so -fno-lto wins.
ENV CFLAGS=-fno-lto CXXFLAGS=-fno-lto LDFLAGS=-fno-lto

RUN apk add --no-cache make gcc g++ python3 linux-headers npm jq && \
    npm install -g "$(jq -r '.packageManager' package.json)" && \
    pnpm config set store-dir /tmp/pnpm-store && \
    # Our zigbee-herdsman is a git-hosted dep, so pnpm builds it from source via its prepack
    # (rimraf + tsc). The base image sets NODE_ENV=production, which would make that nested
    # prepare skip its devDeps; force development for the install so the fork can build, then
    # prune devDependencies back out to keep node_modules prod-only.
    NODE_ENV=development pnpm install --frozen-lockfile --no-optional && \
    pnpm prune --prod && \
    # force serialport to rebuild on the current platform instead of using prebuilds
    rm -rf $(find ./node_modules/.pnpm/ -wholename "*/@serialport/bindings-cpp/prebuilds" -type d) && \
    pnpm rebuild @serialport/bindings-cpp

# --- final: official addon image (HA wrapper) + our overlay ---
FROM ${ADDON_IMAGE} AS final

COPY --from=deps /build/node_modules /app/node_modules
COPY dist /app/dist
COPY index.js package.json /app/

# Wrap the official entrypoint so `prometheus_exporter` in the add-on options reaches
# Zigbee2MQTT's configuration.yaml, then chain to it unchanged. These come from a named build
# context (`--build-context addon=<this repo>/build`), since the main context is the z2m checkout.
COPY --from=addon --chmod=755 rootfs/prometheus-entrypoint.sh /prometheus-entrypoint.sh
COPY --from=addon rootfs/etc/prometheus-exporter-config.js /etc/prometheus-exporter-config.js

ENTRYPOINT ["/sbin/tini", "--", "/prometheus-entrypoint.sh"]
