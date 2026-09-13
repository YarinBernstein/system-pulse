import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // Allows `vite --host` style access from within a Docker container / VM.
    host: true,
    port: 5173,
  },
});
