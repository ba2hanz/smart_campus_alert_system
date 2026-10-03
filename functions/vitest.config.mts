import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Kural testleri emülatöre gidiyor; tek emülatörü paylaştıkları için sırayla.
    testTimeout: 20_000,
    hookTimeout: 60_000,
    fileParallelism: false,
  },
});
