import { env, exports } from "cloudflare:workers";
import { createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { describe, expect, it, vi } from "vitest";
import worker, {
  buildReleaseCacheKey,
  normalizeVersionTag,
  selectReleaseAsset,
} from "../src/index";

const releaseCacheKey = buildReleaseCacheKey("JTXYH", "codex-meter", "CodexMeter-");

describe("update worker", () => {
  it("serves a health response", async () => {
    const response = await exports.default.fetch("https://example.com/health");

    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({ status: "ok" });
  });

  it("returns no body for HEAD requests", async () => {
    const response = await exports.default.fetch("https://example.com/health", {
      method: "HEAD",
    });

    expect(response.status).toBe(200);
    expect(await response.text()).toBe("");
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
  });

  it("does not cache routing errors", async () => {
    const notFound = await exports.default.fetch("https://example.com/missing");
    const methodNotAllowed = await exports.default.fetch("https://example.com/health", {
      method: "POST",
    });

    expect(notFound.status).toBe(404);
    expect(notFound.headers.get("Cache-Control")).toBe("no-store");
    expect(methodNotAllowed.status).toBe(405);
    expect(methodNotAllowed.headers.get("Cache-Control")).toBe("no-store");
  });

  it("normalizes supported GitHub version tags", () => {
    expect(normalizeVersionTag("v1.2.3")).toBe("1.2.3");
    expect(normalizeVersionTag("2.0.0-beta.1+build.7")).toBe("2.0.0-beta.1+build.7");
    expect(() => normalizeVersionTag("latest")).toThrow();
  });

  it("rejects version tags the app cannot parse safely", () => {
    for (const tag of [
      " v1.2.3",
      "v1.2.3 ",
      "1.0.0-",
      "1.0.0-..",
      "1.0.0-alpha..1",
      "1.0.0+",
      "1.0.0+build..1",
      "1.0.0+one+two",
      "1.0.0+build_1",
      "vv1.2.3",
    ]) {
      expect(() => normalizeVersionTag(tag), tag).toThrow();
    }
  });

  it("selects only the unique expected macOS ZIP asset", () => {
    const asset = selectReleaseAsset([
      makeAsset("CodexMeter-1.1.0.zip"),
      makeAsset("CodexMeter-1.1.0-macOS.zip"),
      makeAsset("CodexMeter-1.1.0-macOS.dmg"),
      makeAsset("CodexMeter-1.1.0-macOS.zip", "new"),
      makeAsset("CodexMeter-1.2.0-macOS.zip"),
    ], "CodexMeter-", "1.1.0");

    expect(asset?.name).toBe("CodexMeter-1.1.0-macOS.zip");
    expect(asset?.state).toBe("uploaded");
  });

  it("does not fall back to another platform or an ambiguous asset", () => {
    expect(selectReleaseAsset([
      makeAsset("CodexMeter-1.1.0-Windows.zip"),
    ], "CodexMeter-", "1.1.0")).toBeUndefined();

    const duplicate = makeAsset("CodexMeter-1.1.0-macOS.zip");
    expect(selectReleaseAsset([
      duplicate,
      { ...duplicate, id: 2 },
    ], "CodexMeter-", "1.1.0")).toBeUndefined();
  });

  it("derives the internal cache key from all release configuration", () => {
    expect(buildReleaseCacheKey("JTXYH", "codex-meter", "CodexMeter-"))
      .not.toBe(buildReleaseCacheKey("JTXYH", "codex-meter", "Other-"));
  });

  it("serves the normalized release after the edge cache is populated", async () => {
    await caches.default.delete(releaseCacheKey);
    const githubFetch = stubGitHubFetch(() => Response.json(makeGitHubRelease()));

    try {
      const firstContext = createExecutionContext();
      const firstResponse = await worker.fetch(
        new Request("https://example.com/v1/releases/latest"),
        env,
        firstContext,
      );
      await waitOnExecutionContext(firstContext);

      expect(firstResponse.status).toBe(200);
      expect(firstResponse.headers.get("Cache-Control")).toBe("public, max-age=300");
      expect(firstResponse.headers.get("Cloudflare-CDN-Cache-Control"))
        .toBe("public, max-age=900");
      await expect(firstResponse.json()).resolves.toMatchObject({
        downloadURL: "https://github.com/JTXYH/codex-meter/releases/download/v1.0.0/CodexMeter-1.0.0-macOS.zip",
        fileName: "CodexMeter-1.0.0-macOS.zip",
        version: "1.0.0",
      });

      const secondContext = createExecutionContext();
      const secondResponse = await worker.fetch(
        new Request("https://example.com/v1/releases/latest"),
        env,
        secondContext,
      );
      await waitOnExecutionContext(secondContext);

      expect(secondResponse.status).toBe(200);
      await expect(secondResponse.json()).resolves.toMatchObject({
        downloadURL: "https://github.com/JTXYH/codex-meter/releases/download/v1.0.0/CodexMeter-1.0.0-macOS.zip",
        fileName: "CodexMeter-1.0.0-macOS.zip",
        version: "1.0.0",
      });
      expect(githubFetch).toHaveBeenCalledTimes(1);
      expect(githubFetch).toHaveBeenCalledWith(
        "https://api.github.com/repos/JTXYH/codex-meter/releases/latest",
        expect.objectContaining({ redirect: "manual" }),
      );
      const requestHeaders = new Headers(githubFetch.mock.calls[0]?.[1]?.headers);
      expect(requestHeaders.get("Authorization")).toBe("Bearer test-github-token");
    } finally {
      vi.unstubAllGlobals();
      await caches.default.delete(releaseCacheKey);
    }
  });

  it("rejects release assets outside the configured GitHub repository", async () => {
    await caches.default.delete(releaseCacheKey);
    const githubFetch = stubGitHubFetch(() => Response.json(makeGitHubRelease({
      downloadURL:
        "https://github.com/attacker/codex-meter/releases/download/v1.0.0/CodexMeter-1.0.0-macOS.zip",
    })));

    try {
      const context = createExecutionContext();
      const response = await worker.fetch(
        new Request("https://example.com/v1/releases/latest"),
        env,
        context,
      );
      await waitOnExecutionContext(context);

      expect(response.status).toBe(502);
      expect(response.headers.get("Cache-Control")).toBe("no-store");
    } finally {
      vi.unstubAllGlobals();
      await caches.default.delete(releaseCacheKey);
    }
  });

  it("rejects oversized GitHub release metadata", async () => {
    await caches.default.delete(releaseCacheKey);
    const githubFetch = stubGitHubFetch(() => Response.json(makeGitHubRelease({
      body: "x".repeat(2 * 1024 * 1024),
    })));

    try {
      const context = createExecutionContext();
      const response = await worker.fetch(
        new Request("https://example.com/v1/releases/latest"),
        env,
        context,
      );
      await waitOnExecutionContext(context);

      expect(response.status).toBe(502);
    } finally {
      vi.unstubAllGlobals();
      await caches.default.delete(releaseCacheKey);
    }
  });

  it("rejects query parameters before rate limiting or fetching GitHub", async () => {
    await caches.default.delete(releaseCacheKey);
    const githubFetch = stubGitHubFetch(() => Response.json(makeGitHubRelease()));

    try {
      const context = createExecutionContext();
      const response = await worker.fetch(
        new Request("https://example.com/v1/releases/latest?nonce=cache-bust"),
        env,
        context,
      );
      await waitOnExecutionContext(context);

      expect(response.status).toBe(400);
      expect(response.headers.get("Cache-Control")).toBe("no-store");
      expect(githubFetch).not.toHaveBeenCalled();
    } finally {
      vi.unstubAllGlobals();
      await caches.default.delete(releaseCacheKey);
    }
  });

  it("uses manual redirect handling, rejects 302, and cancels its body", async () => {
    await caches.default.delete(releaseCacheKey);
    const cancel = vi.fn();
    const githubFetch = stubGitHubFetch(() => new Response(
      new ReadableStream({ cancel }),
      {
        status: 302,
        headers: { Location: "https://attacker.example/release" },
      },
    ));

    try {
      const context = createExecutionContext();
      const response = await worker.fetch(
        new Request("https://example.com/v1/releases/latest"),
        env,
        context,
      );
      await waitOnExecutionContext(context);

      expect(response.status).toBe(502);
      expect(githubFetch).toHaveBeenCalledTimes(1);
      expect(githubFetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({ redirect: "manual" }),
      );
      expect(cancel).toHaveBeenCalledTimes(1);
    } finally {
      vi.unstubAllGlobals();
      await caches.default.delete(releaseCacheKey);
    }
  });

  it("rejects a download URL whose tag does not match the release", async () => {
    await caches.default.delete(releaseCacheKey);
    const githubFetch = stubGitHubFetch(() => Response.json(makeGitHubRelease({
      downloadURL:
        "https://github.com/JTXYH/codex-meter/releases/download/v0.9.0/CodexMeter-1.0.0-macOS.zip",
    })));

    try {
      const context = createExecutionContext();
      const response = await worker.fetch(
        new Request("https://example.com/v1/releases/latest"),
        env,
        context,
      );
      await waitOnExecutionContext(context);

      expect(response.status).toBe(502);
      expect(githubFetch).toHaveBeenCalledTimes(1);
    } finally {
      vi.unstubAllGlobals();
      await caches.default.delete(releaseCacheKey);
    }
  });

  it("deletes an invalid cached value and recovers from GitHub", async () => {
    await caches.default.delete(releaseCacheKey);
    await caches.default.put(releaseCacheKey, Response.json({ invalid: true }, {
      headers: { "Cache-Control": "public, max-age=900" },
    }));
    const githubFetch = stubGitHubFetch(() => Response.json(makeGitHubRelease()));
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);

    try {
      const firstContext = createExecutionContext();
      const firstResponse = await worker.fetch(
        new Request("https://example.com/v1/releases/latest"),
        env,
        firstContext,
      );
      await waitOnExecutionContext(firstContext);

      expect(firstResponse.status).toBe(200);

      const secondContext = createExecutionContext();
      const secondResponse = await worker.fetch(
        new Request("https://example.com/v1/releases/latest"),
        env,
        secondContext,
      );
      await waitOnExecutionContext(secondContext);

      expect(secondResponse.status).toBe(200);
      expect(githubFetch).toHaveBeenCalledTimes(1);
      expect(warn).toHaveBeenCalled();
    } finally {
      warn.mockRestore();
      vi.unstubAllGlobals();
      await caches.default.delete(releaseCacheKey);
    }
  });
});

function makeGitHubRelease(options: { body?: string; downloadURL?: string } = {}) {
  return {
    assets: [
      {
        browser_download_url:
          options.downloadURL
          ?? "https://github.com/JTXYH/codex-meter/releases/download/v1.0.0/CodexMeter-1.0.0-macOS.zip",
        content_type: "application/zip",
        digest: `sha256:${"a".repeat(64)}`,
        id: 1,
        name: "CodexMeter-1.0.0-macOS.zip",
        size: 1_405_838,
        state: "uploaded",
      },
    ],
    body: options.body ?? "Release notes",
    html_url: "https://github.com/JTXYH/codex-meter/releases/tag/v1.0.0",
    name: "Codex Meter 1.0.0",
    published_at: "2026-08-09T14:58:30Z",
    tag_name: "v1.0.0",
  };
}

function makeAsset(name: string, state = "uploaded") {
  return {
    browserDownloadURL: `https://github.com/example/releases/download/v1/${name}`,
    contentType: "application/zip",
    digest: null,
    id: 1,
    name,
    size: 1_024,
    state,
  };
}

function stubGitHubFetch(createResponse: () => Response) {
  const githubFetch = vi.fn(async (
    _input: RequestInfo | URL,
    init?: RequestInit,
  ): Promise<Response> => {
    if (init?.redirect !== "manual") {
      throw new TypeError("Cloudflare Workers requires manual redirect handling");
    }
    return createResponse();
  });
  vi.stubGlobal("fetch", githubFetch);
  return githubFetch;
}
