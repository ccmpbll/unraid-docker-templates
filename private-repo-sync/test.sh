#!/bin/bash
# Smoke test against a real public repo: sync, no-op resync, prune-on-change.
set -e
cd "$(dirname "$0")"
export DEST=$(mktemp -d) STATE=$(mktemp -d) CFG=/nonexistent REPOS="ccmpbll/unraid-docker-templates"
slug=ccmpbll-unraid-docker-templates
./private-repo-sync.sh | grep -q synced
n=$(ls "$DEST/$slug"/*.xml | wc -l); [ "$n" -gt 0 ]
[ -z "$(./private-repo-sync.sh)" ]                      # unchanged HEAD -> silent no-op
echo stale > "$DEST/$slug/stale.xml"; echo 0 > "$STATE/$slug"
./private-repo-sync.sh | grep -q synced
[ ! -e "$DEST/$slug/stale.xml" ]                   # resync pruned the stale file
mkdir "$DEST/mine"
REPOS= ./private-repo-sync.sh | grep -q pruned
[ ! -d "$DEST/$slug" ] && [ -d "$DEST/mine" ]     # removed repo pruned, hand-made folder kept
echo "ok ($n templates)"
