#!/usr/bin/env bash
#
# Rebase both fork branches onto the latest upstream stable releases.
#
#   scripts/rebase.sh                 # rebase onto the latest stable of each project
#   scripts/rebase.sh 2.13.0 v10.8.0  # rebase onto specific tags
#
# Clones the forks into src/ if they aren't there yet. Stops with a clear message if a rebase
# conflicts, leaving the checkout mid-rebase for you to resolve by hand (then re-run this script,
# or continue manually and run the push/verify steps yourself).
#
# On success both branches are force-pushed, and zigbee2mqtt's package.json/lockfile are updated
# to pin the freshly rebased zigbee-herdsman commit.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

Z2M_FORK=https://github.com/tomwilkie/zigbee2mqtt.git
Z2M_UPSTREAM=https://github.com/Koenkk/zigbee2mqtt.git
Z2M_BRANCH=prometheus-extension

ZH_FORK=https://github.com/tomwilkie/zigbee-herdsman.git
ZH_UPSTREAM=https://github.com/Koenkk/zigbee-herdsman.git
ZH_BRANCH=metrics-instrumentation

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# clone_fork <dir> <fork-url> <upstream-url> <branch>
clone_fork() {
    local dir=$1 fork=$2 upstream=$3 branch=$4
    if [[ ! -d $dir ]]; then
        log "Cloning $fork into $dir"
        git clone "$fork" "$dir"
        git -C "$dir" remote add upstream "$upstream"
    fi
    git -C "$dir" fetch origin --tags
    git -C "$dir" fetch upstream --tags
    git -C "$dir" checkout "$branch"
    git -C "$dir" reset --hard "origin/$branch"
}

# rebase_onto <dir> <tag> <branch> <upstream-branch> -- rebases the branch's own commits onto <tag>
rebase_onto() {
    local dir=$1 tag=$2 branch=$3 upstream_branch=$4 base
    base=$(git -C "$dir" merge-base "upstream/$upstream_branch" "$branch")
    log "$dir: rebasing $branch (base $(git -C "$dir" rev-parse --short "$base")) onto $tag"
    if ! git -C "$dir" rebase --onto "$tag" "$base" "$branch"; then
        die "Rebase conflicted in $dir. Resolve it there ('git rebase --continue'), then re-run this script."
    fi
}

# ---------------------------------------------------------------- zigbee-herdsman

clone_fork src/zigbee-herdsman "$ZH_FORK" "$ZH_UPSTREAM" "$ZH_BRANCH"

ZH_TAG=${2:-$(gh release view --repo Koenkk/zigbee-herdsman --json tagName --jq .tagName)}
rebase_onto src/zigbee-herdsman "$ZH_TAG" "$ZH_BRANCH" master

log "zigbee-herdsman: build + test"
(cd src/zigbee-herdsman && pnpm install --frozen-lockfile && pnpm run build && pnpm test)

log "zigbee-herdsman: pushing $ZH_BRANCH"
git -C src/zigbee-herdsman push --force-with-lease origin "$ZH_BRANCH"
ZH_SHA=$(git -C src/zigbee-herdsman rev-parse HEAD)
log "zigbee-herdsman is now $ZH_SHA (on $ZH_TAG)"

# ---------------------------------------------------------------- zigbee2mqtt

clone_fork src/zigbee2mqtt "$Z2M_FORK" "$Z2M_UPSTREAM" "$Z2M_BRANCH"

Z2M_TAG=${1:-$(gh release view --repo Koenkk/zigbee2mqtt --json tagName --jq .tagName)}
rebase_onto src/zigbee2mqtt "$Z2M_TAG" "$Z2M_BRANCH" dev

log "zigbee2mqtt: pinning zigbee-herdsman to $ZH_SHA"
(
    cd src/zigbee2mqtt
    node -e '
        const fs = require("fs");
        const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
        p.dependencies["zigbee-herdsman"] = "github:tomwilkie/zigbee-herdsman#" + process.argv[1];
        fs.writeFileSync("package.json", JSON.stringify(p, null, 4) + "\n");
    ' "$ZH_SHA"
    pnpm install
    if ! git diff --quiet -- package.json pnpm-lock.yaml; then
        git commit --quiet -am "DO NOT COMMIT: point zigbee-herdsman at metrics-instrumentation fork" --amend --no-edit
    fi
)

log "zigbee2mqtt: build + test"
(cd src/zigbee2mqtt && pnpm run build && pnpm test)

log "zigbee2mqtt: pushing $Z2M_BRANCH"
git -C src/zigbee2mqtt push --force-with-lease origin "$Z2M_BRANCH"
Z2M_SHA=$(git -C src/zigbee2mqtt rev-parse --short HEAD)

cat <<EOF

Done.

  zigbee-herdsman  $ZH_TAG   -> $(git -C src/zigbee-herdsman rev-parse --short HEAD)
  zigbee2mqtt      $Z2M_TAG  -> $Z2M_SHA

Next:
  scripts/build-push.sh ${Z2M_TAG#v}-$Z2M_SHA
  then bump "version" in zigbee2mqtt-prometheus/config.json to ${Z2M_TAG#v}-$Z2M_SHA,
  add a CHANGELOG.md entry, and commit + push $ROOT.
EOF
