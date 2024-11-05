import { defineConfig } from "vite";
import vitePluginReact from "@vitejs/plugin-react";
import vitePluginRescript from "@jihchi/vite-plugin-rescript";

/**
    @type {import('vite').defineConfig}
*/
export default defineConfig({
  plugins: [vitePluginReact(), vitePluginRescript()],

  server: {
    port: 9001,
  },

  build: {
    rollupOptions: {
      external: ["__buffer__/**", "lib/**"],
    },
  },
});
