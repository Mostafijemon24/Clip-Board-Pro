import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  base: "./",
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    proxy: {
      "/api/tenor": {
        target: "https://api.tenor.com",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/tenor/, "/v1"),
      },
    },
  },
});
