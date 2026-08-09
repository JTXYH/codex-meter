# Codex Meter Update Worker

This Worker reads the latest public GitHub Release for `JTXYH/codex-meter`, selects the macOS ZIP asset, and returns a small update manifest to the app. Release metadata is cached at the Cloudflare edge; release binaries remain on GitHub.

## Endpoints

- `GET /health`
- `GET /v1/releases/latest`

The latest-release endpoint returns `502` until the repository has its first published, non-prerelease GitHub Release with a completed `CodexMeter-*.zip` asset.

## Security

The Worker does not require a GitHub or Cloudflare API token at runtime. The
repository configures a per-client rate limit, bounded upstream responses,
reduced observability sampling, and a GitHub repository allowlist. Free-plan
deployments use Cloudflare's built-in CPU and subrequest limits; do not add a
`limits` block unless the Worker uses the Standard (paid) usage model. Keep the
rate-limit `namespace_id` unique if the same Cloudflare account deploys other
Workers with rate-limit bindings.

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
npx wrangler deploy
```

The production Worker is deployed at `https://codex-meter-updates.tianxiang1314520.workers.dev`.

## FAQ

### Why isn't Claude Code supported?

![Anthropic declined to reinstate the Claude Code account](../../docs/images/why-claude-code-is-not-supported.png)
