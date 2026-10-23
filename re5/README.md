# Re5 CRM

Re5 Agency's CRM for small businesses, built on [Twenty](https://github.com/twentyhq/twenty).
One server hosts every client: each client gets its own workspace at
`<client>.crm.re5agency.com`, with its own isolated data.

## Branches

| Branch | What it is |
| --- | --- |
| `re5` | Production. Twenty's latest release plus Re5 changes. Images are built from here. |
| `main` | An untouched mirror of Twenty's `main`. Keep it in sync with GitHub's **Sync fork** button; never commit to it. |

Re5 work goes on `re5` (or on branches merged into it). Keep changes to Twenty's own
files small: everything Re5-specific lives in `re5/` and
`.github/workflows/re5-build-image.yaml`, so updates from Twenty merge cleanly.

`re5/UPSTREAM_VERSION` records the Twenty release `re5` is based on.

## Licensing

Twenty is AGPLv3, with three things to keep in mind (see `LICENSE`):

- Changes to Twenty's core code must be offered as source to the people using the
  hosted CRM. This fork is public, which covers that.
- Twenty apps built with the SDK (`packages/create-twenty-app`, `twenty-sdk`) can be
  private and proprietary. Re5's client-specific features should be built that way.
- Files marked `/* @license Enterprise */` need a commercial license from Twenty to use.

## How images are built

`.github/workflows/re5-build-image.yaml` runs on every push to `re5` (and from the
Actions tab) and pushes to `ghcr.io/astral8o/twenty` with three tags:

- `latest`
- the Twenty version, e.g. `2.51.0`
- `sha-<commit>`, to pin a server to an exact build

A build takes about 30–60 minutes.

### One-time GitHub setup

1. **Make `re5` the default branch:** Settings → General → Default branch.
2. **Enable Actions:** open the Actions tab and click *I understand my workflows, go ahead and enable them*.
   Twenty's own workflows run on pushes to `main` and on pull requests, so they mostly stay idle. To silence any that
   do run, open the workflow in the Actions tab → ⋯ → *Disable workflow*.
3. **Run the first build:** Actions → *Re5 build image* → *Run workflow* on `re5`.
4. **Make the image public**, so the server can pull it without a login: your GitHub profile →
   Packages → `twenty` → Package settings → Change visibility → Public. The code is
   already public, so this exposes nothing new.

## Deploying the server

### What you need

- A **Hetzner Cloud CPX31** (4 vCPU, 8 GB RAM), Ubuntu 24.04, location closest to your
  clients. Turn on **Backups** when creating it.
- The **re5agency.com** domain on **Cloudflare** (free plan).
- An email provider for invites and password resets, e.g. **Resend** (SMTP).

### 1. DNS (Cloudflare)

Add two **A** records pointing at the server's IP, with the proxy **off** (grey cloud):

| Name | Content |
| --- | --- |
| `crm` | server IP |
| `*.crm` | server IP |

Create an API token: My Profile → API Tokens → Create Token → *Edit zone DNS*
template, limited to the re5agency.com zone. Caddy uses it to get the wildcard HTTPS
certificate that covers every client subdomain.

### 2. Server

```bash
ssh root@<server-ip>

git clone --depth 1 --branch re5 https://github.com/Astral8o/twenty /opt/re5-source
bash /opt/re5-source/re5/deploy/scripts/setup-server.sh
cp -r /opt/re5-source/re5/deploy /opt/re5-crm
cd /opt/re5-crm
cp .env.example .env
```

Fill in `.env`:

```bash
openssl rand -hex 32     # → PG_DATABASE_PASSWORD
openssl rand -base64 32  # → ENCRYPTION_KEY
nano .env                # also CRM_DOMAIN, ACME_EMAIL, CLOUDFLARE_API_TOKEN
```

**Save `.env` in your password manager.** Without `ENCRYPTION_KEY`, the
backups can't decrypt stored credentials.

Start it:

```bash
docker compose up -d --build
docker compose logs -f server   # first start takes a few minutes while it sets up the database
```

### 3. Your admin account

1. Open `https://app.crm.re5agency.com` and sign up with your Re5 email. This creates
   Re5's own workspace.
2. Make yourself a server admin:
   ```bash
   cd /opt/re5-crm && scripts/make-admin.sh you@re5agency.com
   ```
3. Log out and back in. You now have **Settings → Admin Panel** and can create workspaces.

### 4. Nightly backups

```bash
crontab -e
# add:
15 3 * * * /opt/re5-crm/scripts/backup.sh >> /var/log/re5-backup.log 2>&1
```

Dumps go to `/opt/re5-crm-backups` and are kept for `BACKUP_KEEP_DAYS`. Hetzner's server
backups cover the whole disk; for extra safety, copy dumps off-server too
(e.g. Hetzner Storage Box or Backblaze B2).

## Onboarding a client

1. From your admin account, create a workspace for the client and set its subdomain
   (e.g. `acme` → `acme.crm.re5agency.com`).
2. Set up their data model, pipelines and views (and later, Re5 templates/apps).
3. Invite the client's team from Settings → Members.

New sign-ups can't create workspaces on their own (`IS_WORKSPACE_CREATION_LIMITED_TO_SERVER_ADMINS`),
so only Re5 creates client workspaces.

## Updating

### Re5 changes

Push to `re5` → wait for the build → on the server:

```bash
cd /opt/re5-crm && scripts/update.sh
```

`update.sh` backs up the database first, because the server runs database upgrades on start.

### A new Twenty release

1. On GitHub, **Sync fork** on `main`.
2. Merge the new release tag into `re5`, e.g. `twenty/v2.52.0`, and resolve any conflicts.
3. Update `re5/UPSTREAM_VERSION`, push, wait for the build, run `scripts/update.sh`.

Upgrade one release at a time and read Twenty's
[upgrade guide](https://twenty.com/developers/self-host/capabilities/upgrade-guide) first.

### Changing the deploy kit

The server runs from its own copy at `/opt/re5-crm`. When `re5/deploy` changes, copy the
new files over (never overwrite `.env`), then run `docker compose up -d --build`.

## Useful commands

```bash
cd /opt/re5-crm
docker compose ps                 # status
docker compose logs -f server     # server logs
docker compose logs -f worker     # background jobs (email sync, workflows)
docker compose restart server worker
```
