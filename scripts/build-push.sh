#!/usr/bin/env bash
#
# Build and push the add-on image from the zigbee2mqtt fork checkout in src/.
#
#   scripts/build-push.sh                     # tag derived from the checkout: <version>-<sha>
#   scripts/build-push.sh 2.13.0-dd6a6b19     # explicit tag
#   NO_PUSH=1 scripts/build-push.sh           # build locally, don't push
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

TAG=${1:-$(node -p "require('./$SRC/package.json').version")-$(git -C $SRC rev-parse --short HEAD)}

log "Building dist/ in $SRC"
(cd $SRC && pnpm install --frozen-lockfile && pnpm run build)

log "Building $REPO:$TAG (linux/amd64)"
PUSH=(--push)
[[ -n ${NO_PUSH:-} ]] && PUSH=(--load)

docker buildx build \
    --platform linux/amd64 \
    -f "$PWD/build/Dockerfile" \
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
