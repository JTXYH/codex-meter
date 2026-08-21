# Codex Meter Update Worker

This Worker reads the latest public GitHub Release for `JTXYH/codex-meter`, selects the macOS ZIP asset, and returns a small update manifest to the app. Release metadata is cached at the Cloudflare edge; release binaries remain on GitHub.

> Legacy compatibility: Codex Meter 1.2.0 and later use a signed Sparkle appcast from GitHub Releases. Keep this Worker available only for older app versions that still request the JSON update manifest.

## Endpoints

- `GET /health`
- `GET /v1/releases/latest`

The latest-release endpoint returns `502` until the repository has its first
published, non-prerelease GitHub Release with exactly one completed
`CodexMeter-<version>-macOS.zip` asset.
It does not accept query parameters; requests such as `?nonce=...` return `400`
so callers cannot create unbounded edge-cache keys.

## Caching

Workers Caching is enabled for the deployed Worker, including its `workers.dev`
route. Successful update manifests are cached for 15 minutes at Cloudflare's
edge while browsers receive a 5-minute TTL. The health response and all error
responses are marked `no-store`.

The Worker also keeps a configuration-scoped Cache API entry as a fallback for
custom-domain or routed deployments where the Cache API is functional. Cache
API operations have no effect on `*.workers.dev`, so they are not the production
cache layer for the URL below.

## Security

The Worker requires a fine-grained GitHub token with read-only `Contents`
permission for this repository. Store it only as the `GITHUB_TOKEN` Cloudflare
secret; never add its value to Wrangler configuration or Git. The repository
configures a per-client rate limit, bounded upstream responses, manual redirect
rejection, exact release-tag and macOS asset matching, reduced observability
sampling, and a GitHub repository allowlist. Free-plan deployments use
Cloudflare's built-in CPU and subrequest limits; do not add a `limits` block
unless the Worker uses the Standard (paid) usage model. Keep the rate-limit
`namespace_id` unique if the same Cloudflare account deploys other Workers with
rate-limit bindings.

For a paid Cloudflare account, also configure a budget alert in the dashboard.
Application-level rate limiting reduces abusive work but cannot prevent every
billable invocation from a distributed attack.

## Development

```bash
npm ci
npm test
npm run check
```

## Deployment

```bash
npx wrangler secret put GITHUB_TOKEN
npx wrangler deploy
```

The production Worker is deployed at `https://codex-meter-updates.tianxiang1314520.workers.dev`.

## License

This Worker is part of Codex Meter and is licensed under the [MIT License](../../LICENSE).

## FAQ

### Why isn't Claude Code supported?

![Anthropic declined to reinstate the Claude Code account](../../docs/images/why-claude-code-is-not-supported.png)
