import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

process.env.GITHUB_TOKEN = "test-github-token";

export default defineConfig({
  plugins: [
    cloudflareTest({
      miniflare: {
        bindings: {
          GITHUB_TOKEN: "test-github-token",
        },
      },
      wrangler: {
        configPath: "./wrangler.jsonc",
      },
    }),
  ],
});
