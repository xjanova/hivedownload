# NetwixSync

Mirrors **rongyok** episodes that you've imported into **NetWix** (https://netwix.online) onto
NetWix's own storage, so they stream reliably without depending on rongyok's expiring Discord URLs.

## Why this exists

rongyok only serves *fresh, playable* video URLs to **residential IPs**. The NetWix server
(a datacenter IP) always receives already‑expired links → 404. So the download has to happen from
a residential machine (your PC), then get uploaded to NetWix. That's exactly what this tool does:

```
NetWix  ──/api/ingest/pending──►  "please mirror these episodes"
  PC    ──resolve+download──────►  rongyok (fresh URL, residential IP)
  PC    ──/api/ingest/episode──►  upload MP4 → NetWix stores it, marks it mirrored
NetWix streams the file from its own /storage (no expiry, seekable)
```

## Usage

1. In NetWix admin → **นำเข้าหนัง**, import the rongyok titles you want (this creates the
   episodes NetWix will ask to have mirrored).
2. On your PC (residential internet), run:

```bash
dotnet run --project src/NetwixSync -- --token <NETWIX_INGEST_TOKEN>
```

The ingest token is on the server at `/home/admin/.netwix_ingest_token`.

### Options

| flag | default | meaning |
|------|---------|---------|
| `--token <t>` | (env `NETWIX_INGEST_TOKEN`) | NetWix ingest token — **required** |
| `--netwix <url>` | `https://netwix.online` | NetWix base URL |
| `--source <s>` | `rongyok` | which source to mirror |
| `--limit <n>` | `300` | max episodes per run |
| `--retries <n>` | `3` | download attempts per episode |

Re-run any time — it only fetches episodes NetWix still needs (idempotent). Schedule it
(Task Scheduler / cron) to keep new imports mirrored automatically.

> Only **rongyok** needs mirroring. **wow-drama** already streams fine straight through NetWix's
> server-side HLS proxy, so it is not part of this tool.
