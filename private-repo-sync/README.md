# private-repo-sync

Unraid plugin that mirrors Docker/plugin XML templates from your own GitHub repos into
Community Applications' **Private Apps** folder (`/boot/config/plugins/community.applications/private/`),
so you don't wait on the CA feed.

Install: Plugins → Install Plugin →
`https://github.com/ccmpbll/unraid-docker-templates/raw/master/private-repo-sync/private-repo-sync.plg`

Settings page: Tools → User Utilities → **Private Repo Sync** (repos, schedule, token, Sync now). Or edit the file directly:

Config: `/boot/config/plugins/private-repo-sync/private-repo-sync.cfg`
- `REPOS` space-separated `user/repo[@branch]`
- `SCHEDULE` cron expression (default hourly); run `private-repo-sync.sh cron` after editing
- `GITHUB_TOKEN` optional, for private repos / higher rate limit

Syncs at install, at every boot, and on schedule. A repo is only downloaded when its HEAD commit changed;
templates deleted upstream are removed locally. Manual run: `/boot/config/plugins/private-repo-sync/private-repo-sync.sh`.

Templates from repos you remove from the list are deleted from Private Apps on the next sync (only folders this plugin created).
The GitHub token is stored in plain text in the cfg on the flash drive; use a read-only, single-purpose token.
