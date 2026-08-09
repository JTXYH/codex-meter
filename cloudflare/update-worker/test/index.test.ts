import { env, exports } from "cloudflare:workers";
import { createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { describe, expect, it, vi } from "vitest";
import worker, { normalizeVersionTag, selectReleaseAsset } from "../src/index";

const releaseCacheKey = "https://codex-meter.internal/v1/releases/latest";

describe("update worker", () => {
  it("serves a health response", async () => {
    const response = await exports.default.fetch("https://example.com/health");

    expect(response.status).toBe(200);
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

  it("normalizes supported GitHub version tags", () => {
    expect(normalizeVersionTag("v1.2.3")).toBe("1.2.3");
    expect(normalizeVersionTag("2.0.0-beta.1")).toBe("2.0.0-beta.1");
    expect(() => normalizeVersionTag("latest")).toThrow();
  });

  it("prefers the macOS ZIP asset and ignores incomplete uploads", () => {
    const asset = selectReleaseAsset([
      makeAsset("CodexMeter-1.1.0.zip"),
      makeAsset("CodexMeter-1.1.0-macOS.zip"),
      makeAsset("CodexMeter-1.1.0-macOS.dmg"),
      makeAsset("CodexMeter-1.1.0-macOS.zip", "new"),
    ], "CodexMeter-");

    expect(asset?.name).toBe("CodexMeter-1.1.0-macOS.zip");
    expect(asset?.state).toBe("uploaded");
  });

  it("serves the normalized release after the edge cache is populated", async () => {
    await caches.default.delete(releaseCacheKey);
    const githubFetch = vi.fn(async () => Response.json(makeGitHubRelease()));
    vi.stubGlobal("fetch", githubFetch);

    try {
      const firstContext = createExecutionContext();
      const firstResponse = await worker.fetch(
        new Request("https://example.com/v1/releases/latest"),
        env,
        firstContext,
      );
      await waitOnExecutionContext(firstContext);

      expect(firstResponse.status).toBe(200);
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
    } finally {
      vi.unstubAllGlobals();
      await caches.default.delete(releaseCacheKey);
    }
  });

  it("rejects release assets outside the configured GitHub repository", async () => {
    await caches.default.delete(releaseCacheKey);
    const githubFetch = vi.fn(async () => Response.json(makeGitHubRelease({
      downloadURL:
        "https://github.com/attacker/codex-meter/releases/download/v1.0.0/CodexMeter-1.0.0-macOS.zip",
    })));
    vi.stubGlobal("fetch", githubFetch);

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
    const githubFetch = vi.fn(async () => Response.json(makeGitHubRelease({
      body: "x".repeat(2 * 1024 * 1024),
    })));
    vi.stubGlobal("fetch", githubFetch);

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
