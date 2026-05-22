# Plan: Hosting & API Layer for DataForNerdsCollectors JSON Output

## Context

Today the `get-windows-update-history.yml` workflow runs the collectors on a GitHub-hosted runner and writes JSON to **stdout only** — nothing is persisted or published. The repo's `.gitignore` (`output/`, `data/`, `downloads/`) signals that scraped output is meant to live outside the repo. To make the data useful to PowerShell users and other consumers, the runner needs to publish JSON to a hosted location, with a path to grow into:

- URL-parameter format conversion (JSON / XML / CSV / Text)
- API keys + per-key quotas

Total payload across all three collectors is ~250 KB (Windows Update ~100 KB, Language Codes ~15 KB, M365 Apps ~150 KB). Cost and bandwidth are non-issues; the architecture choice is driven by **edge functions + custom domain + cheap KV** for phase 2/3.

## Recommended Stack: Cloudflare

| Layer | Service | Phase | Why |
|---|---|---|---|
| Object storage | **Cloudflare R2** | 1 | No egress fees, S3-compatible API, free tier covers this dataset many times over |
| Edge compute | **Cloudflare Workers** | 2 | Sits in front of R2; reshapes JSON → XML/CSV/Text based on URL params; ~100k req/day free, $5/mo for 10M |
| API-key store | **Workers KV** | 3 | Cheap, eventually-consistent KV — perfect for API key lookup at the edge |
| DNS + TLS | **Cloudflare DNS** | 1 | Free TLS on custom domain; no extra service needed |
| Deploy | **`wrangler` action in GH Actions** | 1 | Replaces stdout dump with `wrangler r2 object put` |

Everything lives in one vendor with one auth token in GitHub Actions secrets. Custom domain (e.g. `api.dataforneds.dev`) terminates TLS at Cloudflare for free.

### Alternatives considered (rejected for this use case)

- **GitHub Pages / gh-pages branch** — free and easy for phase 1, but no path to format conversion or API keys without bolting on a separate platform later. Skipped to avoid a phase-2 rewrite.
- **AWS S3 + CloudFront + Lambda@Edge + API Gateway usage plans** — most enterprise-grade option (built-in API keys & quotas via usage plans), but higher complexity and egress-fee exposure for a tiny project. Worth revisiting only if you outgrow Cloudflare's free Workers limits.
- **Vercel + Vercel KV** — comparable DX to Cloudflare; less attractive because Vercel charges for bandwidth past the free tier where Cloudflare R2 does not.
- **Azure Static Web Apps + Functions** — fine if you already lived in Azure; no advantage here over Cloudflare and slightly worse free tier.

## Phase 1 — Static JSON Publishing (shippable on its own)

**Goal:** GH Actions writes JSON to a public URL on every run.

- Create an R2 bucket (e.g. `dfn-collectors`) and enable public access (or front it with a Worker route).
- Bind a custom domain (e.g. `data.dataforneds.dev`) to the bucket via Cloudflare's R2 → custom domain feature.
- Files to publish per run:
  - `/v1/windows-update-history.json`
  - `/v1/language-codes.json`
  - `/v1/microsoft365-apps-update-history.json`
  - `/v1/manifest.json` — list of available datasets + `lastUpdated` ISO timestamp + record counts. Useful for clients that want to detect freshness without downloading the body.
- Update `.github/workflows/get-windows-update-history.yml` (and rename to something like `publish-collectors.yml`):
  - Replace the stdout dump with `ConvertTo-Json -Depth 5 | Out-File` per collector.
  - Use `cloudflare/wrangler-action` to `wrangler r2 object put` each file.
  - Add a cron trigger (e.g. daily at 06:00 UTC) in addition to manual `workflow_dispatch`.
- Secrets to add to the repo: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

After phase 1 a PowerShell user can do:

```powershell
Invoke-RestMethod 'https://data.dataforneds.dev/v1/windows-update-history.json'
```

## Phase 2 — Format Conversion via URL Params

**Goal:** Same data, returned as JSON / XML / CSV / Text based on the request.

- Add a Workers project (new top-level `api/` directory in this repo, deployed via the same workflow with a separate `wrangler deploy` step).
- Route pattern: `api.dataforneds.dev/v1/{dataset}` with `?format=json|xml|csv|text` (default `json`). Also honor `Accept` header.
- Worker pulls the underlying JSON from the R2 binding (zero-egress, fast) and converts:
  - **JSON** — passthrough.
  - **CSV** — flatten using the known schema (all three collectors are flat objects, so this is trivial).
  - **XML** — wrap each record in `<record>` tags; element names = field names.
  - **Text** — tab-separated or pipe-separated, header on first line.
- Add `ETag` / `Cache-Control` headers so clients (and Cloudflare's edge cache) avoid re-fetching.
- Keep `data.dataforneds.dev/v1/*.json` from phase 1 working as the unauthenticated "raw" path for power users and as a fallback.

## Phase 3 — API Keys + Quotas

**Goal:** Optional auth for higher rate limits, analytics per key, future paid tiers.

- Workers KV namespace `api-keys` with entries like `{ "owner": "chris", "tier": "free", "createdAt": "..." }`.
- Worker checks `Authorization: Bearer <key>` (or `?key=`) on each request:
  - No key → low anonymous rate limit (e.g. 60 req/hr per IP via Workers rate-limiting binding).
  - Valid key → higher tier limits, plus per-key counters tracked in KV or Durable Objects.
- Build a tiny admin endpoint (or just a `wrangler kv:key put` runbook) for issuing keys — no UI needed until there's demand.
- Add Workers Analytics Engine logging for request → key → format breakdown so future tier design has real data.

## Files to Modify / Create

- `.github/workflows/get-windows-update-history.yml` → rename + rewrite to publish all three collectors to R2 (phase 1).
- New `api/` directory containing a Workers project with `wrangler.toml`, `src/index.ts` (or `.js`), R2 binding, KV binding (phase 2/3).
- New `scripts/publish.ps1` (optional) that wraps "run all collectors, write JSON to `output/`, upload to R2" so it can be run locally for testing before pushing workflow changes.
- No changes required inside `Modules/DataForNerdsCollectors/` itself — the module already returns JSON-serializable PSCustomObject arrays.

## Verification

**Phase 1**

1. Run the updated workflow via `workflow_dispatch`; confirm three JSON files + manifest land at `https://data.dataforneds.dev/v1/...` with correct `Content-Type`.
2. From a fresh PowerShell session: `Invoke-RestMethod` each URL, confirm the shape matches the existing module output (same field names, same record count as a local `Get-* | Measure-Object` run).
3. Confirm the cron trigger fires the next day and updates the `lastUpdated` field in `manifest.json`.

**Phase 2**

1. `curl -H 'Accept: text/csv' https://api.dataforneds.dev/v1/windows-update-history` → returns CSV with the 9 expected columns.
2. Same URL with `?format=xml`, `?format=text` → spot-check structure.
3. Hit the endpoint twice; second request shows `cf-cache-status: HIT`.

**Phase 3**

1. Unauthenticated burst above the anonymous limit returns 429.
2. Request with a valid key in KV gets through; with an invalid key returns 401.
3. KV counter for the test key increments per request.
