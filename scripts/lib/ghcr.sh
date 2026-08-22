# Registry lookups against ghcr.io, shared by build-push.sh and check-updates.sh so there is one
# implementation of "which add-on image revision is current".
#
# Source it, don't run it:  . "$(dirname "$0")/lib/ghcr.sh"

# ghcr_latest_revision <repo> <version> -- highest N among the <version>-N tags of ghcr.io/<repo>,
# or nothing if the version has no such tag. The official add-on images are tagged
# <z2m-version>-<addon-revision> (e.g. 2.13.0-1); the revision moves when the add-on wrapper, OS or
# Node changes without Zigbee2MQTT itself being released.
ghcr_latest_revision() {
    local repo=$1 version=$2 token

    token=$(curl -sf "https://ghcr.io/token?scope=repository:$repo:pull&service=ghcr.io" |
        node -p "JSON.parse(require('fs').readFileSync(0,'utf8')).token") || return 1

    curl -sf -H "Authorization: Bearer $token" "https://ghcr.io/v2/$repo/tags/list" |
        node -e '
            const {tags} = JSON.parse(require("fs").readFileSync(0, "utf8"));
            const v = process.argv[1];
            const revs = tags
                .filter((t) => t.startsWith(v + "-"))
                .map((t) => Number(t.slice(v.length + 1)))
                .filter((n) => Number.isInteger(n));
            if (revs.length) console.log(Math.max(...revs));
        ' "$version"
}
