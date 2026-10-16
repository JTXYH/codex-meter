# Codex Meter update service

This Cloudflare Worker serves the JSON update manifest used by early Codex Meter releases. Codex Meter 2.0 uses the signed Sparkle feed on GitHub and does not call this service. Keep the Worker running so older installations can still discover the latest release.

## Endpoints

- `GET /health`: service health.
- `GET /v1/releases/latest`: latest published, non-prerelease GitHub release and its matching `CodexMeter-<version>-macOS.zip` asset. `HEAD` is also supported.

The release endpoint rejects query parameters and returns `502` when GitHub is unavailable or a valid download is missing. ZIP files stay on GitHub; the Worker returns metadata only.

## Configuration

The repository and asset prefix are set in `wrangler.jsonc`. `GITHUB_TOKEN` is a Cloudflare secret with read-only Contents access to the configured repository. Do not commit the token or place it in the configuration file.

The implementation validates the GitHub host, repository, tag and asset name, bounds response sizes, rejects redirects, and rate-limits requests. Successful manifests use a 15-minute edge cache and a 5-minute browser cache. Errors and health responses are not cached.

## Development and deployment

```bash
npm ci
npm test
npm run check
```

`check` validates TypeScript, generated bindings and a deployment dry run. To deploy an intentional Worker change:

```bash
npx wrangler secret put GITHUB_TOKEN
npx wrangler deploy
```

Publishing a Codex Meter release does not require redeploying this Worker. It reads the repository's latest release automatically.

See the [app README](../../README.en.md), [2.0 release notes](../../docs/releases/v2.0.0.md) and [MIT License](../../LICENSE).
