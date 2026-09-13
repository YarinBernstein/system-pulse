/**
 * Runtime configuration resolution.
 *
 * Vite normally bakes `import.meta.env.VITE_*` values in at BUILD time,
 * which is a poor fit for a container image that should be configurable
 * per-environment (dev / staging / k8s) without rebuilding. To work around
 * this, the Nginx container's entrypoint script generates `/config.js` at
 * *container startup* from the real environment, exposing it as
 * `window.__ENV__`. That takes priority; the Vite build-time value is kept
 * only as a fallback for local `npm run dev`.
 */
declare global {
  interface Window {
    __ENV__?: {
      VITE_BACKEND_URL?: string;
    };
  }
}

export const BACKEND_URL: string =
  window.__ENV__?.VITE_BACKEND_URL ||
  import.meta.env.VITE_BACKEND_URL ||
  "http://localhost:8000";
