#!/usr/bin/env bash
#
# Build and push the add-on image from the zigbee2mqtt fork checkout in src/.
#
#   scripts/build-push.sh                     # tag derived from the checkout: <version>-<sha>
#   scripts/build-push.sh 2.13.0-dd6a6b19     # explicit tag
#   NO_PUSH=1 scripts/build-push.sh           # build locally, don't push
#   ADDON_IMAGE=... scripts/build-push.sh     # override the base image
#
# The base image defaults to the official stable add-on image for the Zigbee2MQTT release in
# src/zigbee2mqtt (ghcr.io/zigbee2mqtt/zigbee2mqtt-amd64:<version>-<rev>), resolved below.
#
# Requires: src/zigbee2mqtt (see scripts/rebase.sh), docker buildx, and `docker login` for
# Docker Hub. Only amd64 is built — see zigbee2mqtt-prometheus/config.json's "arch".

set -euo pipefail

cd "$(dirname "$0")/.."

. scripts/lib/ghcr.sh

REPO=docker.io/tomwilkie/zigbee2mqtt-prometheus-amd64
SRC=src/zigbee2mqtt

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ -d $SRC ]] || die "$SRC not found — run scripts/rebase.sh first."

Z2M_VERSION=$(node -p "require('./$SRC/package.json').version")
TAG=${1:-$Z2M_VERSION-$(git -C $SRC rev-parse --short HEAD)}

# Base image: the official *stable* add-on image for this Zigbee2MQTT release. Tags are
# <version>-<addon-revision> (e.g. 2.13.0-1); pick the highest revision published for our version
# so the wrapper, OS and Node we overlay onto are pinned and version-matched. Override with
# ADDON_IMAGE=... if you need a specific base.
if [[ -z ${ADDON_IMAGE:-} ]]; then
    BASE_REPO=zigbee2mqtt/zigbee2mqtt-amd64
    log "Resolving base image tag for Zigbee2MQTT $Z2M_VERSION"
    rev=$(ghcr_latest_revision "$BASE_REPO" "$Z2M_VERSION")
    [[ -n $rev ]] || die "No ghcr.io/$BASE_REPO tag for Zigbee2MQTT $Z2M_VERSION. The add-on image for this release may not be published yet; pass ADDON_IMAGE=... to override."
    ADDON_IMAGE=ghcr.io/$BASE_REPO:$Z2M_VERSION-$rev
fi
log "Base image: $ADDON_IMAGE"

log "Building dist/ in $SRC"
(cd $SRC && pnpm install --frozen-lockfile && pnpm run build)

log "Building $REPO:$TAG (linux/amd64)"
PUSH=(--push)
[[ -n ${NO_PUSH:-} ]] && PUSH=(--load)

docker buildx build \
    --platform linux/amd64 \
    -f "$PWD/build/Dockerfile" \
    --build-arg "ADDON_IMAGE=$ADDON_IMAGE" \
    --build-context "addon=$PWD/build" \
    -t "$REPO:$TAG" \
    "${PUSH[@]}" \
    "$SRC"

# Record what was published in build/versions.json, the state scripts/check-updates.sh compares
# upstream against. Only on a real push: an unpushed local build hasn't changed what's out there.
# upstream_addon is left alone — it tracks the hand-done re-sync against hassio-zigbee2mqtt.
if [[ -z ${NO_PUSH:-} ]]; then
    Z2M_TAG=$(git -C $SRC describe --tags --abbrev=0 HEAD 2>/dev/null || echo "$Z2M_VERSION")
    Z2M_SHA=$(git -C $SRC rev-parse HEAD)
    if [[ -d src/zigbee-herdsman ]]; then
        ZH_TAG=$(git -C src/zigbee-herdsman describe --tags --abbrev=0 HEAD 2>/dev/null || echo "")
        ZH_SHA=$(git -C src/zigbee-herdsman rev-parse HEAD)
    else
        ZH_TAG="" ZH_SHA=""
    fi

    node -e '
        const fs = require("fs");
        const file = "build/versions.json";
        const v = JSON.parse(fs.readFileSync(file, "utf8"));
        const [z2mTag, z2mSha, zhTag, zhSha, baseImage] = process.argv.slice(1);
        v.zigbee2mqtt = {tag: z2mTag, fork_sha: z2mSha};
        // Keep the recorded herdsman pin if src/zigbee-herdsman is not checked out here.
        if (zhTag && zhSha) v.zigbee_herdsman = {tag: zhTag, fork_sha: zhSha};
        v.base_image = baseImage;
        fs.writeFileSync(file, JSON.stringify(v, null, 4) + "\n");
    ' "$Z2M_TAG" "$Z2M_SHA" "$ZH_TAG" "$ZH_SHA" "$ADDON_IMAGE"

    log "Recorded the new pinned state in build/versions.json"
    git diff --stat -- build/versions.json || true
fi

cat <<EOF

Pushed (or built) $REPO:$TAG

Next:
  - bump "version" in zigbee2mqtt-prometheus/config.json to $TAG
  - add a zigbee2mqtt-prometheus/CHANGELOG.md entry
  - commit + push this repo (including build/versions.json, updated above); Home Assistant
    will then offer the update
EOF
