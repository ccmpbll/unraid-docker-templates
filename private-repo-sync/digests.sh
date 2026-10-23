#!/bin/bash
# Check the .plg's <SHA256> pins against the files they pin; "digests.sh update" rewrites them.
cd "$(dirname "$0")/.."
plg=private-repo-sync/private-repo-sync.plg rc=0
for m in scriptURL:private-repo-sync/private-repo-sync.sh pageURL:private-repo-sync/private-repo-sync.page iconURL:images/private-repo-sync.png; do
  ent=${m%%:*} f=${m#*:}
  new=$(shasum -a 256 "$f" | cut -d' ' -f1)
  old=$(perl -0ne "print \$1 if m|<URL>&$ent;</URL>\s*<SHA256>(\w+)<|" "$plg")
  [ "$old" = "$new" ] && continue
  if [ "$1" = update ]; then perl -0pi -e "s|(<URL>&$ent;</URL>\s*<SHA256>)\w+|\${1}$new|" "$plg"; echo "updated $f"
  else echo "STALE: $f (plg has $old, file is $new); run private-repo-sync/digests.sh update"; rc=1; fi
done
exit $rc
