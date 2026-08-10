const GITHUB_API_VERSION = "2026-03-10";
const RELEASE_CACHE_NAMESPACE = "https://codex-meter.internal/v2/releases/latest";
const RELEASE_CACHE_SECONDS = 900;
const RELEASE_BROWSER_CACHE_SECONDS = 300;
const MAXIMUM_GITHUB_RESPONSE_BYTES = 2 * 1024 * 1024;
const MAXIMUM_CACHED_RELEASE_BYTES = 256 * 1024;
const MAXIMUM_RELEASE_NOTES_LENGTH = 64 * 1024;
const MAXIMUM_RELEASE_TITLE_LENGTH = 256;
const MAXIMUM_VERSION_LENGTH = 128;
const MAXIMUM_ASSET_BYTES = 512 * 1024 * 1024;
const VERSION_PATTERN = /^\d+(?:\.\d+){1,3}(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;

type JsonObject = Record<string, unknown>;

interface GitHubReleaseAsset {
  browserDownloadURL: string;
  contentType: string;
  digest: string | null;
  id: number;
  name: string;
  size: number;
  state: string;
}

interface GitHubRelease {
  assets: GitHubReleaseAsset[];
  body: string;
  htmlURL: string;
  name: string;
  publishedAt: string;
  tagName: string;
}

interface CachedRelease {
  asset: GitHubReleaseAsset;
  notes: string;
  publishedAt: string;
  releasePageURL: string;
  tagName: string;
  title: string;
  version: string;
}

interface PublicRelease {
  digest: string | null;
  downloadURL: string;
  fileName: string;
  fileSize: number;
  notes: string;
  publishedAt: string;
  releasePageURL: string;
  title: string;
  version: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/v1/releases/latest" && url.search !== "") {
      return responseForRequest(request, jsonResponse(
        { error: "Query parameters are not supported" },
        400,
        { "Cache-Control": "no-store" },
      ));
    }

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          ...corsHeaders(),
          ...securityHeaders(),
          "Access-Control-Max-Age": "86400",
          "Cache-Control": "public, max-age=86400",
        },
      });
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      return jsonResponse({ error: "Method not allowed" }, 405, {
        Allow: "GET, HEAD, OPTIONS",
        "Cache-Control": "no-store",
      });
    }

    try {
      if (url.pathname === "/health") {
        return responseForRequest(request, jsonResponse(
          { status: "ok" },
          200,
          { "Cache-Control": "no-store" },
        ));
      }

      if (url.pathname === "/v1/releases/latest") {
        const rateLimit = await env.UPDATE_RATE_LIMITER.limit({
          key: `release:${clientIdentifier(request)}`,
        });
        if (!rateLimit.success) {
          return responseForRequest(request, jsonResponse(
            { error: "Too many requests" },
            429,
            {
              "Cache-Control": "no-store",
              "Retry-After": "60",
            },
          ));
        }

        const release = await loadLatestRelease(env, ctx);
        return responseForRequest(request, publicReleaseResponse(release));
      }

      return responseForRequest(request, jsonResponse(
        { error: "Not found" },
        404,
        { "Cache-Control": "no-store" },
      ));
    } catch (error) {
      console.error(JSON.stringify({
        message: "update request failed",
        error: error instanceof Error ? error.message : "Unknown error",
        path: url.pathname,
      }));
      return responseForRequest(
        request,
        jsonResponse(
          { error: "Update service is temporarily unavailable" },
          502,
          { "Cache-Control": "no-store" },
        ),
      );
    }
  },
} satisfies ExportedHandler<Env>;

async function loadLatestRelease(env: Env, ctx: ExecutionContext): Promise<CachedRelease> {
  const cache = caches.default;
  const cacheKey = new Request(buildReleaseCacheKey(
    env.GITHUB_OWNER,
    env.GITHUB_REPO,
    env.ASSET_PREFIX,
  ));
  let cachedResponse: Response | undefined;
  try {
    cachedResponse = await cache.match(cacheKey);
  } catch (error) {
    logCacheError("release cache read failed", error);
  }

  if (cachedResponse) {
    try {
      return parseCachedRelease(
        await readLimitedJSONResponse(
          cachedResponse,
          MAXIMUM_CACHED_RELEASE_BYTES,
          "cached release",
        ),
        env.GITHUB_OWNER,
        env.GITHUB_REPO,
        env.ASSET_PREFIX,
      );
    } catch (error) {
      logCacheError("cached release was invalid", error);
      await cache.delete(cacheKey).catch((deleteError: unknown) => {
        logCacheError("invalid release cache deletion failed", deleteError);
      });
    }
  }

  const githubResponse = await fetch(
    `https://api.github.com/repos/${encodeURIComponent(env.GITHUB_OWNER)}/${encodeURIComponent(env.GITHUB_REPO)}/releases/latest`,
    {
      headers: githubHeaders(env.GITHUB_TOKEN),
      redirect: "manual",
    },
  );

  if (githubResponse.status >= 300 && githubResponse.status < 400) {
    await cancelResponseBody(githubResponse);
    throw new Error(`GitHub latest release request redirected with ${githubResponse.status}`);
  }
  if (!githubResponse.ok) {
    await cancelResponseBody(githubResponse);
    throw new Error(`GitHub latest release request returned ${githubResponse.status}`);
  }

  const githubRelease = parseGitHubRelease(
    await readLimitedJSONResponse(
      githubResponse,
      MAXIMUM_GITHUB_RESPONSE_BYTES,
      "GitHub release",
    ),
    env.GITHUB_OWNER,
    env.GITHUB_REPO,
  );
  const version = normalizeVersionTag(githubRelease.tagName);
  const asset = selectReleaseAsset(
    githubRelease.assets,
    env.ASSET_PREFIX,
    version,
  );
  if (!asset) {
    throw new Error("Latest release does not contain a matching macOS ZIP asset");
  }
  requireExactGitHubReleasePath(
    githubRelease.htmlURL,
    "GitHub release page URL",
    env.GITHUB_OWNER,
    env.GITHUB_REPO,
    "tag",
    githubRelease.tagName,
  );
  requireExactGitHubReleasePath(
    asset.browserDownloadURL,
    "GitHub download URL",
    env.GITHUB_OWNER,
    env.GITHUB_REPO,
    "download",
    githubRelease.tagName,
    asset.name,
  );

  const release: CachedRelease = {
    asset,
    notes: githubRelease.body,
    publishedAt: githubRelease.publishedAt,
    releasePageURL: githubRelease.htmlURL,
    tagName: githubRelease.tagName,
    title: githubRelease.name || githubRelease.tagName,
    version,
  };
  const cacheResponse = Response.json(release, {
    headers: {
      "Cache-Control": `public, max-age=${RELEASE_CACHE_SECONDS}`,
    },
  });
  ctx.waitUntil(cache.put(cacheKey, cacheResponse).catch((error: unknown) => {
    console.error(JSON.stringify({
      message: "release cache write failed",
      error: error instanceof Error ? error.message : "Unknown error",
    }));
  }));
  return release;
}

function publicReleaseResponse(release: CachedRelease): Response {
  const payload: PublicRelease = {
    digest: release.asset.digest,
    downloadURL: release.asset.browserDownloadURL,
    fileName: release.asset.name,
    fileSize: release.asset.size,
    notes: release.notes,
    publishedAt: release.publishedAt,
    releasePageURL: release.releasePageURL,
    title: release.title,
    version: release.version,
  };
  return jsonResponse(payload, 200, {
    "Cache-Control": `public, max-age=${RELEASE_BROWSER_CACHE_SECONDS}`,
    "Cloudflare-CDN-Cache-Control": `public, max-age=${RELEASE_CACHE_SECONDS}`,
  });
}

function githubHeaders(token: string): Headers {
  return new Headers({
    Accept: "application/vnd.github+json",
    Authorization: `Bearer ${token}`,
    "User-Agent": "CodexMeter-Update-Service",
    "X-GitHub-Api-Version": GITHUB_API_VERSION,
  });
}

export function normalizeVersionTag(tagName: string): string {
  if (tagName !== tagName.trim()) {
    throw new Error("Latest release tag is not a supported version");
  }
  const normalized = tagName.replace(/^[vV](?=\d)/, "");
  if (normalized.length > MAXIMUM_VERSION_LENGTH || !VERSION_PATTERN.test(normalized)) {
    throw new Error("Latest release tag is not a supported version");
  }
  return normalized;
}

export function selectReleaseAsset(
  assets: readonly GitHubReleaseAsset[],
  prefix: string,
  version: string,
): GitHubReleaseAsset | undefined {
  const expectedName = `${prefix}${version}-macOS.zip`;
  const candidates = assets.filter((asset) => {
    return asset.state === "uploaded"
      && asset.name === expectedName
      && asset.size > 0
      && asset.size <= MAXIMUM_ASSET_BYTES;
  });

  return candidates.length === 1 ? candidates[0] : undefined;
}

function parseGitHubRelease(value: unknown, owner: string, repo: string): GitHubRelease {
  const object = requireObject(value, "GitHub release");
  const rawAssets = object.assets;
  if (!Array.isArray(rawAssets)) {
    throw new Error("GitHub release assets are missing");
  }

  return {
    assets: rawAssets.map((asset) => parseGitHubReleaseAsset(asset, owner, repo)),
    body: optionalString(object.body).slice(0, MAXIMUM_RELEASE_NOTES_LENGTH),
    htmlURL: requireGitHubReleaseURL(
      object.html_url,
      "GitHub release page URL",
      owner,
      repo,
      "tag",
    ),
    name: optionalString(object.name).slice(0, MAXIMUM_RELEASE_TITLE_LENGTH),
    publishedAt: requireString(object.published_at, "GitHub published date"),
    tagName: requireString(object.tag_name, "GitHub release tag"),
  };
}

function parseGitHubReleaseAsset(
  value: unknown,
  owner: string,
  repo: string,
): GitHubReleaseAsset {
  const object = requireObject(value, "GitHub release asset");
  return {
    browserDownloadURL: requireGitHubReleaseURL(
      object.browser_download_url,
      "GitHub download URL",
      owner,
      repo,
      "download",
    ),
    contentType: requireString(object.content_type, "GitHub asset content type"),
    digest: optionalSHA256Digest(object.digest, "GitHub asset digest"),
    id: requirePositiveInteger(object.id, "GitHub asset ID"),
    name: requireSafeAssetName(object.name, "GitHub asset name"),
    size: requireNonnegativeInteger(object.size, "GitHub asset size"),
    state: requireString(object.state, "GitHub asset state"),
  };
}

function parseCachedReleaseAsset(
  value: unknown,
  owner: string,
  repo: string,
): GitHubReleaseAsset {
  const object = requireObject(value, "cached release asset");
  return {
    browserDownloadURL: requireGitHubReleaseURL(
      object.browserDownloadURL,
      "cached download URL",
      owner,
      repo,
      "download",
    ),
    contentType: requireString(object.contentType, "cached content type"),
    digest: optionalSHA256Digest(object.digest, "cached asset digest"),
    id: requirePositiveInteger(object.id, "cached asset ID"),
    name: requireSafeAssetName(object.name, "cached asset name"),
    size: requireAssetSize(object.size, "cached asset size"),
    state: requireString(object.state, "cached asset state"),
  };
}

function parseCachedRelease(
  value: unknown,
  owner: string,
  repo: string,
  assetPrefix: string,
): CachedRelease {
  const object = requireObject(value, "cached release");
  const asset = parseCachedReleaseAsset(object.asset, owner, repo);
  const tagName = requireString(object.tagName, "cached release tag");
  const rawVersion = requireString(object.version, "cached release version");
  const version = normalizeVersionTag(rawVersion);
  if (rawVersion !== version || normalizeVersionTag(tagName) !== version) {
    throw new Error("cached release version does not match its tag");
  }
  if (selectReleaseAsset([asset], assetPrefix, version) !== asset) {
    throw new Error("cached release asset is not the expected macOS ZIP");
  }
  const releasePageURL = requireGitHubReleaseURL(
    object.releasePageURL,
    "cached release page URL",
    owner,
    repo,
    "tag",
  );
  requireExactGitHubReleasePath(
    releasePageURL,
    "cached release page URL",
    owner,
    repo,
    "tag",
    tagName,
  );
  requireExactGitHubReleasePath(
    asset.browserDownloadURL,
    "cached download URL",
    owner,
    repo,
    "download",
    tagName,
    asset.name,
  );

  return {
    asset,
    notes: optionalString(object.notes).slice(0, MAXIMUM_RELEASE_NOTES_LENGTH),
    publishedAt: requireString(object.publishedAt, "cached published date"),
    releasePageURL,
    tagName,
    title: requireString(object.title, "cached release title")
      .slice(0, MAXIMUM_RELEASE_TITLE_LENGTH),
    version,
  };
}

function requireObject(value: unknown, label: string): JsonObject {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error(`${label} is invalid`);
  }
  return Object.fromEntries(Object.entries(value));
}

function requireString(value: unknown, label: string): string {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${label} is invalid`);
  }
  return value;
}

function optionalString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function requirePositiveInteger(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${label} is invalid`);
  }
  return value;
}

function requireNonnegativeInteger(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${label} is invalid`);
  }
  return value;
}

function requireAssetSize(value: unknown, label: string): number {
  if (typeof value !== "number"
    || !Number.isSafeInteger(value)
    || value <= 0
    || value > MAXIMUM_ASSET_BYTES) {
    throw new Error(`${label} is invalid`);
  }
  return value;
}

function requireSafeAssetName(value: unknown, label: string): string {
  const name = requireString(value, label);
  if (name.length > 255 || /[\u0000-\u001F\u007F/\\]/.test(name)) {
    throw new Error(`${label} is invalid`);
  }
  return name;
}

function optionalSHA256Digest(value: unknown, label: string): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  const digest = requireString(value, label);
  if (!/^sha256:[0-9a-f]{64}$/i.test(digest)) {
    throw new Error(`${label} is invalid`);
  }
  return digest.toLowerCase();
}

function requireGitHubReleaseURL(
  value: unknown,
  label: string,
  owner: string,
  repo: string,
  route: "download" | "tag",
): string {
  const string = requireString(value, label);
  const url = new URL(string);
  const expectedPath = `/${owner}/${repo}/releases/${route}/`.toLowerCase();
  if (url.protocol !== "https:"
    || url.hostname.toLowerCase() !== "github.com"
    || url.port !== ""
    || url.username !== ""
    || url.password !== ""
    || url.search !== ""
    || url.hash !== ""
    || !url.pathname.toLowerCase().startsWith(expectedPath)
    || url.pathname.length <= expectedPath.length) {
    throw new Error(`${label} is not trusted`);
  }
  return url.toString();
}

function requireExactGitHubReleasePath(
  value: string,
  label: string,
  owner: string,
  repo: string,
  route: "download" | "tag",
  tagName: string,
  assetName?: string,
): void {
  const url = new URL(value);
  let segments: string[];
  try {
    segments = url.pathname.split("/").slice(1).map((segment) => decodeURIComponent(segment));
  } catch {
    throw new Error(`${label} is not trusted`);
  }

  const expectedSegments = [owner, repo, "releases", route, tagName];
  if (route === "download") {
    if (!assetName) {
      throw new Error(`${label} is not trusted`);
    }
    expectedSegments.push(assetName);
  }

  const matches = segments.length === expectedSegments.length
    && segments.every((segment, index) => {
      const expected = expectedSegments[index];
      if (expected === undefined) {
        return false;
      }
      return index < 2
        ? segment.toLowerCase() === expected.toLowerCase()
        : segment === expected;
    });
  if (!matches) {
    throw new Error(`${label} does not match the release tag and asset`);
  }
}

export function buildReleaseCacheKey(owner: string, repo: string, assetPrefix: string): string {
  const url = new URL(RELEASE_CACHE_NAMESPACE);
  url.searchParams.set("owner", owner);
  url.searchParams.set("repo", repo);
  url.searchParams.set("assetPrefix", assetPrefix);
  return url.toString();
}

async function readLimitedJSONResponse(
  response: Response,
  maximumBytes: number,
  label: string,
): Promise<unknown> {
  const contentLength = response.headers.get("Content-Length");
  if (contentLength !== null) {
    const declaredBytes = Number(contentLength);
    if (Number.isFinite(declaredBytes) && declaredBytes > maximumBytes) {
      await cancelResponseBody(response);
      throw new Error(`${label} exceeds the response size limit`);
    }
  }

  if (!response.body) {
    throw new Error(`${label} response body is missing`);
  }

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      if (totalBytes + value.byteLength > maximumBytes) {
        await reader.cancel(`${label} exceeds the response size limit`).catch(() => undefined);
        throw new Error(`${label} exceeds the response size limit`);
      }
      totalBytes += value.byteLength;
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const body = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }

  try {
    return JSON.parse(new TextDecoder("utf-8", {
      fatal: true,
      ignoreBOM: false,
    }).decode(body));
  } catch {
    throw new Error(`${label} is not valid UTF-8 JSON`);
  }
}

async function cancelResponseBody(response: Response): Promise<void> {
  await response.body?.cancel().catch(() => undefined);
}

function logCacheError(message: string, error: unknown): void {
  console.warn(JSON.stringify({
    message,
    error: error instanceof Error ? error.message : "Unknown error",
  }));
}

function clientIdentifier(request: Request): string {
  const connectingIP = request.headers.get("CF-Connecting-IP")?.trim();
  return (connectingIP || "unknown").slice(0, 128);
}

function responseForRequest(request: Request, response: Response): Response {
  return request.method === "HEAD"
    ? new Response(null, {
      status: response.status,
      statusText: response.statusText,
      headers: response.headers,
    })
    : response;
}

function jsonResponse(payload: unknown, status = 200, headers: HeadersInit = {}): Response {
  return Response.json(payload, {
    status,
    headers: {
      ...corsHeaders(),
      ...securityHeaders(),
      ...headers,
    },
  });
}

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
    "Access-Control-Allow-Origin": "*",
  };
}

function securityHeaders(): Record<string, string> {
  return {
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "Permissions-Policy": "camera=(), geolocation=(), microphone=()",
    "Referrer-Policy": "no-referrer",
    "X-Frame-Options": "DENY",
    "X-Content-Type-Options": "nosniff",
  };
}
