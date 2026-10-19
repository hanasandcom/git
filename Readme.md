# Hanasand Git Server

This repository contains the Docker Compose configuration and host scripts for
the self-hosted Forgejo Git service at `git.hanasand.com`. It manages Forgejo
and its PostgreSQL database; it is not the Forgejo application source code.

## What runs here

`docker-compose.yml` starts two containers:

| Service | Purpose | Host access |
| --- | --- | --- |
| `git` | Forgejo web UI, Git over SSH, and the Forgejo REST API | `127.0.0.1:8000` (HTTP) and `127.0.0.1:2222` (SSH) |
| `git_db` | PostgreSQL database used by Forgejo | `127.0.0.1:15432` (diagnostics/admin only) |

The web and SSH ports bind to loopback and are expected to be published through
the host's reverse proxy and firewall. Containers communicate over Compose's
private network. Forgejo stores repositories and application data in the
`git_git_data` volume; PostgreSQL stores its database in `git_git_db_data`.
Both volumes are declared external, so this stack will not create or remove
them automatically.

Forgejo Actions and its runner are **disabled/not included** in this stack.
Workflows will not run here. The Forgejo REST API is provided by Forgejo at
`https://git.hanasand.com/api/v1`; this repository does not implement a separate
bot or application API.

## Requirements

- Docker Engine with the Compose plugin
- A reverse proxy configured to send HTTPS traffic to `127.0.0.1:8000`
- Existing Docker volumes named `git_git_data` and `git_git_db_data`
- A strong database password stored in a local `.env` file

The Compose file pins Forgejo to version `16.0.5` by image digest and PostgreSQL
to major version `18`. Review and test image changes before upgrading production.

## Start the stack

Run these commands from the directory containing `docker-compose.yml`:

```sh
cat > .env <<'EOF'
DB_PASSWD=replace-with-a-long-random-password
EOF
chmod 600 .env

docker volume create git_git_data
docker volume create git_git_db_data
docker compose up -d
docker compose ps
```

Only create those volumes for a new installation. On an existing host, inspect
both volumes and confirm they contain the expected production data before
starting or restoring the stack. If either is missing on a production host,
stop and investigate instead of creating an empty replacement. Do not remove
volumes to troubleshoot a container.

The first run may require completing Forgejo's setup in the web UI. Confirm the
database connection uses PostgreSQL and that the public/root URL matches the
HTTPS hostname configured in the reverse proxy.

## Check service health

```sh
docker compose ps
docker compose logs --tail=100 git git_db
curl -fsS http://127.0.0.1:8000/api/healthz
curl -fsS https://git.hanasand.com/api/v1/version
```

The health endpoint should report `status: pass`, including successful database
and cache checks. The version endpoint reports the running Forgejo version.
These checks confirm current service health; they do not verify backups,
replication, or historical uptime.

## Data, backup, and restore

The Compose named volumes hold the Git service's persistent state. Back up both
`git_git_data` and `git_git_db_data` using a consistent, tested procedure before
upgrades or maintenance. Keep encrypted copies off the production host and
regularly test restoration to a separate environment. A filesystem copy of a
live PostgreSQL data directory is not, by itself, a reliable database backup;
use a PostgreSQL-aware backup or stop the database for a coordinated volume
backup.

The scripts under `scripts/` also include an optional primary-to-standby
replication/synchronization setup. It assumes the host paths, SSH account, key,
port, and volume names documented in the script defaults. Review and configure
those values for the actual hosts before installing its systemd timers. The
sync script checks that the standby is still in recovery and stopped before it
copies Forgejo data; it does not perform automatic failover. Confirm PostgreSQL
replication and the standby's state independently during recovery drills.
The sync script defaults to copying a `git_runner_data` volume for older runner
setups. Since this Compose stack has no runner, set `SYNC_RUNNER_DATA=0` when
installing or running sync unless that volume is intentionally in use.

## Maintenance scripts

- `scripts/forgejo-doctor.sh` runs selected Forgejo repository-integrity checks.
  Its default is `FIX=1`, which applies the doctor's supported repairs. Set
  `FIX=0` for a check-only run.
- `scripts/sync-to-ovh.sh` synchronizes Forgejo files to a fenced standby and
  checks PostgreSQL WAL replay. Review its defaults and SSH trust setup before
  running it.
- `scripts/install-maintenance.sh` installs systemd timers for the doctor and
  standby sync. Run it only on the intended primary host, as root, after
  configuring the scripts and verifying the standby.
- `scripts/ensure-git-stack.sh` starts the Compose stack from
  `/home/hanasand/git` and is intended for that host layout.

These operational scripts can change or repair production state. Inspect their
configuration and logs before relying on them; a successful command is not a
substitute for checking the service and backup/replication state.

## Configuration and security notes

- Keep `.env`, SSH private keys, and backup material out of Git. The repository
  ignores `.env`.
- Registration and OpenID signup are disabled; new accounts must be provisioned
  by an administrator.
- The default repository visibility is private.
- The PostgreSQL host port is loopback-bound for local administration. Remove
  that port mapping if host-side database access is not required.
- Forgejo Actions are disabled in this Compose configuration. If CI is enabled
  in the future, configure and isolate runners separately before accepting
  untrusted workflows.

## Useful links

- Forgejo web service: <https://git.hanasand.com>
- Forgejo API: <https://git.hanasand.com/api/v1>
- Forgejo API documentation: <https://forgejo.org/docs/latest/user/api/>
