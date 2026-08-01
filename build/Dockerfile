# Builds a Home Assistant Zigbee2MQTT addon image carrying the prometheus-extension branch.
#
# Strategy: derive from the official "edge" addon image, which already provides the HA s6/bashio
# wrapper, the OS, Node, and ABI-compatible native @serialport bindings. A deps stage runs
# `pnpm install` from the fork's lockfile to produce the exact prod dependency closure (incl.
# prom-client and the zigbee-herdsman metrics fork), then the final stage overlays that
# node_modules plus the locally-built dist/ and index.js onto the wrapper.
#
# Both stages share the same base image, so the recompiled @serialport binary is ABI-correct
# for the runtime.
#
# Build context is the zigbee2mqtt checkout (src/zigbee2mqtt), NOT this repo — see
# scripts/build-push.sh. `pnpm run build` must have been run there first so dist/ exists.
#
# If the edge image ever stops being a suitable base (e.g. its Node major diverges from the
# fork's requirements), the fallback is to adapt common/Dockerfile from
# zigbee2mqtt/hassio-zigbee2mqtt, which builds from source onto ghcr.io/home-assistant/{arch}-base
# and would mean vendoring its rootfs (s6 services, entrypoint, healthcheck) here too.

ARG ADDON_IMAGE=ghcr.io/zigbee2mqtt/zigbee2mqtt-edge-amd64:edge

# --- deps: compute the fork's exact prod closure (mirrors docker/Dockerfile's deps stage) ---
FROM ${ADDON_IMAGE} AS deps

WORKDIR /build

COPY package.json pnpm-lock.yaml ./

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

# --- final: edge addon image (HA wrapper) + our overlay ---
FROM ${ADDON_IMAGE} AS final

COPY --from=deps /build/node_modules /app/node_modules
COPY dist /app/dist
COPY index.js package.json /app/
