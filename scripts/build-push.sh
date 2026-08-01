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
    token=$(curl -sf "https://ghcr.io/token?scope=repository:$BASE_REPO:pull&service=ghcr.io" |
        node -p "JSON.parse(require('fs').readFileSync(0,'utf8')).token")
    rev=$(curl -sf -H "Authorization: Bearer $token" "https://ghcr.io/v2/$BASE_REPO/tags/list" |
        node -e '
            const {tags} = JSON.parse(require("fs").readFileSync(0, "utf8"));
            const v = process.argv[1];
            const revs = tags
                .filter((t) => t.startsWith(v + "-"))
                .map((t) => Number(t.slice(v.length + 1)))
                .filter((n) => Number.isInteger(n));
            if (revs.length) console.log(Math.max(...revs));
        ' "$Z2M_VERSION")
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
    -t "$REPO:$TAG" \
    "${PUSH[@]}" \
    "$SRC"

cat <<EOF

Pushed (or built) $REPO:$TAG

Next:
  - bump "version" in zigbee2mqtt-prometheus/config.json to $TAG
  - add a zigbee2mqtt-prometheus/CHANGELOG.md entry
  - commit + push this repo; Home Assistant will then offer the update
EOF
