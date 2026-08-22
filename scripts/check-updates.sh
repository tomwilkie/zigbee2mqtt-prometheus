#!/usr/bin/env bash
#
# Is there anything upstream worth rebuilding for?
#
#   scripts/check-updates.sh              # human-readable report; exit 1 if there is
#   scripts/check-updates.sh --markdown   # the same report as a GitHub issue body
#   scripts/check-updates.sh --github     # also write has_updates/title to $GITHUB_OUTPUT
#
# Read-only: it queries GitHub and ghcr.io and writes nothing but its own output. Run daily by
# .github/workflows/check-updates.yml, which turns the report into an issue.
#
# Compares build/versions.json (what the published image is built from) against upstream:
#
#   1. a newer Zigbee2MQTT stable release
#   2. a different zigbee-herdsman pin *in that release* — the runbook targets whatever the z2m
#      release pins, not herdsman's own latest, which is reported as information only
#   3. a newer revision of the official add-on base image for our Zigbee2MQTT version
#   4. changes to the upstream add-on definition we mirror (config.json / DOCS.md)
#   5. either upstream PR no longer being open — if they merge, this add-on is redundant
#
# Requires: gh (authenticated), node, curl.

set -euo pipefail

cd "$(dirname "$0")/.."

. scripts/lib/ghcr.sh

VERSIONS=build/versions.json
CONFIG=zigbee2mqtt-prometheus/config.json

Z2M_REPO=Koenkk/zigbee2mqtt
ZH_REPO=Koenkk/zigbee-herdsman
BASE_REPO=zigbee2mqtt/zigbee2mqtt-amd64
ADDON_REPO=zigbee2mqtt/hassio-zigbee2mqtt
Z2M_PR=31645
ZH_PR=1751

MODE=text
case ${1:-} in
    --markdown) MODE=markdown ;;
    --github) MODE=github ;;
    "") ;;
    *) echo "usage: $0 [--markdown|--github]" >&2; exit 2 ;;
esac

die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 2; }

command -v gh >/dev/null || die "gh not found"
[[ -f $VERSIONS ]] || die "$VERSIONS not found"

json() { node -p "JSON.parse(require('fs').readFileSync('$1','utf8'))$2 ?? ''"; }

# ------------------------------------------------------------------ pinned state

PINNED_Z2M=$(json $VERSIONS ".zigbee2mqtt.tag")
PINNED_ZH=$(json $VERSIONS ".zigbee_herdsman.tag")
PINNED_BASE=$(json $VERSIONS ".base_image")
PINNED_BASE_REV=${PINNED_BASE##*-}
ADDON_VERSION=$(json $CONFIG ".version")

# ------------------------------------------------------------------ upstream state

# `gh release view` with no tag returns the latest non-prerelease release.
LATEST_Z2M=$(gh release view --repo $Z2M_REPO --json tagName --jq .tagName)
LATEST_ZH=$(gh release view --repo $ZH_REPO --json tagName --jq .tagName)

# The herdsman version to target is the one the z2m release we'd build pins.
TARGET_Z2M=$LATEST_Z2M
TARGET_ZH=v$(gh api "repos/$Z2M_REPO/contents/package.json?ref=$TARGET_Z2M" \
    -H "Accept: application/vnd.github.raw" |
    node -p "JSON.parse(require('fs').readFileSync(0,'utf8')).dependencies['zigbee-herdsman']")

# Base image revision for the Zigbee2MQTT version we would build.
LATEST_BASE_REV=$(ghcr_latest_revision "$BASE_REPO" "$TARGET_Z2M" || true)

# Upstream add-on definition: latest commit touching each mirrored path.
addon_head() {
    gh api "repos/$ADDON_REPO/commits?path=$1&per_page=1" --jq '.[0].sha'
}

Z2M_PR_STATE=$(gh pr view $Z2M_PR --repo $Z2M_REPO --json state --jq .state)
ZH_PR_STATE=$(gh pr view $ZH_PR --repo $ZH_REPO --json state --jq .state)

# ------------------------------------------------------------------ compare

findings=()        # version moves — these mean rebase + rebuild
resync_findings=() # upstream add-on definition changes — these mean editing our copies

if [[ $LATEST_Z2M != "$PINNED_Z2M" ]]; then
    findings+=("**Zigbee2MQTT $LATEST_Z2M** is out (we build $PINNED_Z2M) — <https://github.com/$Z2M_REPO/releases/tag/$LATEST_Z2M>")
fi

if [[ $TARGET_ZH != "$PINNED_ZH" ]]; then
    findings+=("**zigbee-herdsman $TARGET_ZH** is what Zigbee2MQTT $TARGET_Z2M pins (we build $PINNED_ZH)")
fi

if [[ -n $LATEST_BASE_REV && $TARGET_Z2M == "$PINNED_Z2M" && $LATEST_BASE_REV != "$PINNED_BASE_REV" ]]; then
    findings+=("**Base image revision $TARGET_Z2M-$LATEST_BASE_REV** is published (we build on $PINNED_BASE) — the official add-on wrapper, OS or Node moved without a Zigbee2MQTT release")
fi

for path in "zigbee2mqtt/config.json" "zigbee2mqtt/DOCS.md"; do
    pinned=$(json $VERSIONS "[\"upstream_addon\"][\"$path\"]")
    head=$(addon_head "$path")
    if [[ -n $head && $head != "$pinned" ]]; then
        resync_findings+=("**\`$path\` changed upstream** — re-sync ours against [$ADDON_REPO@${head:0:8}](https://github.com/$ADDON_REPO/commits/$head/$path), then update \`upstream_addon\` in \`build/versions.json\`")
    fi
done

pr_findings=()
[[ $Z2M_PR_STATE != OPEN ]] &&
    pr_findings+=("[$Z2M_REPO#$Z2M_PR](https://github.com/$Z2M_REPO/pull/$Z2M_PR) is **$Z2M_PR_STATE**")
[[ $ZH_PR_STATE != OPEN ]] &&
    pr_findings+=("[$ZH_REPO#$ZH_PR](https://github.com/$ZH_REPO/pull/$ZH_PR) is **$ZH_PR_STATE**")

has_updates=0
[[ ${#findings[@]} -gt 0 || ${#resync_findings[@]} -gt 0 || ${#pr_findings[@]} -gt 0 ]] && has_updates=1

# ------------------------------------------------------------------ report

title="Upstream updates available"
if [[ ${#pr_findings[@]} -gt 0 ]]; then
    if [[ ${#findings[@]} -gt 0 || ${#resync_findings[@]} -gt 0 ]]; then
        title="Upstream updates available, and a PR changed state"
    else
        title="Upstream PR state changed"
    fi
fi

markdown() {
    if [[ ${#pr_findings[@]} -gt 0 ]]; then
        echo "### The upstream PRs moved"
        echo
        for f in "${pr_findings[@]}"; do echo "- $f"; done
        echo
        echo "If they merged, the official add-on carries the exporter and this repo can be retired —"
        echo "see the README. If they were closed, decide whether to keep carrying the branches."
        echo
    fi

    if [[ ${#findings[@]} -gt 0 ]]; then
        echo "### Rebuild"
        echo
        for f in "${findings[@]}"; do echo "- $f"; done
        echo
        echo '```sh'
        echo "scripts/rebase.sh $TARGET_Z2M $TARGET_ZH"
        echo "scripts/build-push.sh"
        echo '```'
        echo
        echo "Then bump \`version\` in \`zigbee2mqtt-prometheus/config.json\`, add a \`CHANGELOG.md\` entry,"
        echo "and commit (\`build/versions.json\` is updated by the build). Full runbook: README."
        echo
    fi

    if [[ ${#resync_findings[@]} -gt 0 ]]; then
        echo "### Re-sync the add-on definition"
        echo
        for f in "${resync_findings[@]}"; do echo "- $f"; done
        echo
        echo "This is an edit to our \`config.json\`/\`DOCS.md\`, not a rebuild — though if a rebuild is"
        echo "also due above, do both in one release."
        echo
    fi

    echo "### State"
    echo
    echo "| | Built | Upstream |"
    echo "| --- | --- | --- |"
    echo "| Zigbee2MQTT | \`$PINNED_Z2M\` | \`$LATEST_Z2M\` |"
    echo "| zigbee-herdsman | \`$PINNED_ZH\` | \`$TARGET_ZH\` (pinned by $TARGET_Z2M; latest release is \`$LATEST_ZH\`) |"
    echo "| Base image | \`$PINNED_BASE\` | \`ghcr.io/$BASE_REPO:$TARGET_Z2M-${LATEST_BASE_REV:-?}\` |"
    echo "| Add-on | \`$ADDON_VERSION\` | |"
    echo
    echo "<sub>Generated by \`scripts/check-updates.sh\`.</sub>"
}

case $MODE in
    text)
        if [[ $has_updates == 1 ]]; then
            printf '\033[1m%s\033[0m\n\n' "$title"
        else
            printf '\033[1mNothing to do.\033[0m\n\n'
        fi
        markdown | sed 's/^/  /'
        ;;
    markdown)
        markdown
        ;;
    github)
        markdown
        {
            echo "has_updates=$has_updates"
            echo "title=$title"
            echo "body<<CHECK_UPDATES_EOF"
            markdown
            echo "CHECK_UPDATES_EOF"
        } >>"${GITHUB_OUTPUT:?--github requires \$GITHUB_OUTPUT}"
        ;;
esac

exit $has_updates
