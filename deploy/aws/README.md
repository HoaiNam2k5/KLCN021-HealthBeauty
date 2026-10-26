# Existing EC2 API/web update

This release targets the existing `demo-api` Compose stack at `/home/ubuntu/demo-api`.
The running API's Compose labels identify the active base and SePay override files.
Existing SQL Server, Caddy, volumes and all environment values remain unchanged.

Before pulling, save SHA256 hashes and private backups of the server's three local
Docker/nginx files in `releases/20261025-invoice/protected-before.json` and a private
backup directory. The JSON keys are paths relative to `source`, and values are hashes:
`HealthBeauty.Api/Dockerfile`, `HealthBeauty.Web/Dockerfile`, `HealthBeauty.Web/nginx.conf`.
Do not print or commit Compose snapshots, credentials, or private backups.

After an approved fast-forward pull, run as the Ubuntu deployment user:

```bash
cd /home/ubuntu/demo-api/source
python3 deploy/aws/release.py prepare
# Both Linux source builds and preservation checks must pass before activation.
python3 deploy/aws/release.py activate
```

Preparation builds from .NET 8/Node 24 source and inherits the exact running runtime
images. It preserves appsettings and nginx files, tags both old images for rollback,
and creates image-only `compose.release.yaml` and `compose.rollback.yaml`. It stops
if these overrides already exist. Private snapshots/logs are stored with restrictive
permissions outside Git at `releases/20261025-invoice/private`.

Activation recreates only `api` and `web`, verifies HTTPS, web asset bytes, API DLL
bytes, all environment values and file hashes, and confirms SQL/Caddy container IDs.
Failed activation checks restore both previous images and verify readiness/config.
No migration, database write, database restore or volume deletion is performed.

Manual rollback:

```bash
python3 /home/ubuntu/demo-api/source/deploy/aws/release.py rollback
```

Always include all three Compose files for later operations. After rollback, the
release override still references the new images: use the rollback override until
the release override is deliberately corrected.

```bash
cd /home/ubuntu/demo-api
sudo docker compose -p demo-api -f compose.yaml -f compose.sepay.yaml \
  -f compose.release.yaml ps
```

Run guard regressions locally with `python deploy/aws/test_release.py`. Before another
release, use a new release directory/ID and deliberately review existing overrides.
The original Windows Dockerfile and server-local Docker/nginx files are not replaced.

For the next approved release, preserve the current active Compose files and choose
a separate release ID. Keep existing release overrides as the base; the new override
only replaces API/web image tags, and rollback points to the immediately previous pair.

```bash
export HEALTHBEAUTY_RELEASE_ID=20261026-payments
# Back up the three local Docker/nginx files and write protected-before.json under
# releases/20261026-payments before preparation, as for the first release.
python3 /home/ubuntu/demo-api/source/deploy/aws/release.py prepare
python3 /home/ubuntu/demo-api/source/deploy/aws/release.py activate
# Only if rollback is needed, with the same release ID:
python3 /home/ubuntu/demo-api/source/deploy/aws/release.py rollback
```

The new override filenames are `compose.release.20261026-payments.yaml` and
`compose.rollback.20261026-payments.yaml`. Continue using all previously active
Compose files plus the appropriate new override. Omitting `HEALTHBEAUTY_RELEASE_ID`
retains access to the original release's state for backward-compatible rollback.
