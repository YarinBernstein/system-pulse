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

// Deliberately checked against `undefined` rather than `||`: an empty
// string is a valid, intentional runtime value (call the API on the same
// origin as the page, via Nginx's reverse proxy) and must not fall through
// to the localhost fallback below just because it's falsy.
const runtimeBackendUrl = window.__ENV__?.VITE_BACKEND_URL;

export const BACKEND_URL: string =
  runtimeBackendUrl !== undefined
    ? runtimeBackendUrl
    : import.meta.env.VITE_BACKEND_URL || "http://localhost:8000";
