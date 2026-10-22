#!/bin/bash
# private-repo-sync: mirror Unraid templates from GitHub repos into Community Applications' private folder.
#   private-repo-sync        sync every repo in REPOS (skips repos whose HEAD commit is unchanged)
#   private-repo-sync cron   (re)write the cron entry from SCHEDULE
# Always run as `bash <this file>`: /boot is vfat and has no exec bit.
NAME=private-repo-sync
CFG=${CFG:-/boot/config/plugins/$NAME/$NAME.cfg}
DEST=${DEST:-/boot/config/plugins/community.applications/private}
STATE=${STATE:-/tmp/$NAME}   # RAM on purpose: forces one resync after every reboot, spares the flash drive

# cfg is read as data, never sourced: REPOS="user/repo user/repo@branch", SCHEDULE="17 * * * *", GITHUB_TOKEN=""
if [ -f "$CFG" ]; then
  while IFS== read -r k v || [ -n "$k" ]; do
    v=${v#\"}; v=${v%\"}
    case $k in REPOS|SCHEDULE|GITHUB_TOKEN) printf -v "$k" %s "$v" ;; esac
  done < "$CFG"
fi

log() { echo "$*"; logger -t "$NAME" "$*" 2>/dev/null; }

if [ "$1" = cron ]; then
  f=/boot/config/plugins/dynamix/$NAME.cron
  printf '# %s\n%s /bin/bash /boot/config/plugins/%s/%s.sh >/dev/null 2>&1\n\n' "$NAME" "${SCHEDULE:-17 * * * *}" "$NAME" "$NAME" > "$f"
  update_cron
  exit
fi

# curl for GitHub; the token goes in via stdin so it never shows up in `ps`
gh() {
  { [ -n "$GITHUB_TOKEN" ] && printf 'header = "Authorization: Bearer %s"\n' "$GITHUB_TOKEN"; } \
    | curl -fsS --connect-timeout 10 --max-time 120 -K - "$@"
}
mkdir -p "$DEST" "$STATE"

sync_repo() {
  local spec=$1 repo=${1%@*} ref=HEAD
  [[ $spec == *@* ]] && ref=${spec#*@}
  local slug=${repo//\//-} sha tmp
  # ponytail: unauthenticated GitHub API = 60 req/hr/IP; 1 call per unchanged repo, set GITHUB_TOKEN if that bites
  sha=$(gh -H 'Accept: application/vnd.github.sha' "https://api.github.com/repos/$repo/commits/$ref") \
    || { log "$spec: cannot resolve commit"; return 1; }
  [ "$sha" = "$(cat "$STATE/$slug" 2>/dev/null)" ] && [ -d "$DEST/$slug" ] && return 0

  tmp=$(mktemp -d) || return 1   # /tmp, not $DEST: an interrupted run must not leave junk where CA looks
  mkdir "$tmp/src" "$tmp/out"
  if gh -L "https://api.github.com/repos/$repo/tarball/$sha" | tar -xzf - -C "$tmp/src"; then
    find "$tmp/src" -name '*.xml' ! -name ca_profile.xml -not -path '*/.*' | while IFS= read -r f; do
      [ -e "$tmp/out/${f##*/}" ] && log "$spec: duplicate ${f##*/} skipped" || cp "$f" "$tmp/out"
    done
  fi
  if [ -n "$(ls -A "$tmp/out")" ]; then
    touch "$tmp/out/.managed"   # marks folders we own, so pruning never touches hand-made ones
    rm -rf "$DEST/$slug"; mv "$tmp/out" "$DEST/$slug"; echo "$sha" > "$STATE/$slug"
    log "$spec: synced ${sha:0:7}"
  else
    log "$spec: download failed or no templates found, keeping existing"
  fi
  rm -rf "$tmp"
}

wanted=" "
for r in $REPOS; do s=${r%@*}; wanted+="${s//\//-} "; sync_repo "$r"; done

# Drop mirrors of repos no longer listed. REPOS unset (cfg missing) means "unknown", not "none": prune nothing.
if [ -n "${REPOS+x}" ]; then
  for d in "$DEST"/*/; do
    [ -e "$d.managed" ] && [[ $wanted != *" $(basename "$d") "* ]] && { rm -rf "$d"; log "pruned ${d%/}"; }
  done
fi
