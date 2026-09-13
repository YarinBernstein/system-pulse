import { useCallback, useEffect, useState } from "react";
import { Database, Radio, Server } from "lucide-react";
import { StatusCard } from "./components/StatusCard";
import { PulseButton } from "./components/PulseButton";
import { BACKEND_URL } from "./config";
import type { PulseResponse, ServiceStatus } from "./types";

const POLL_INTERVAL_MS = 5000;

async function checkEndpoint(path: string): Promise<ServiceStatus> {
  try {
    const res = await fetch(`${BACKEND_URL}${path}`, { method: "GET" });
    return res.ok ? "up" : "down";
  } catch {
    // Network error (backend unreachable, DNS failure, CORS, timeout, etc).
    return "down";
  }
}

export default function App() {
  const [backendStatus, setBackendStatus] = useState<ServiceStatus>("checking");
  const [dbStatus, setDbStatus] = useState<ServiceStatus>("checking");
  const [pulseCount, setPulseCount] = useState<number | null>(null);
  const [lastError, setLastError] = useState<string | null>(null);

  const refreshStatuses = useCallback(async () => {
    const [backend, db] = await Promise.all([
      checkEndpoint("/api/health"),
      checkEndpoint("/api/db-status"),
    ]);
    setBackendStatus(backend);
    setDbStatus(db);
  }, []);

  useEffect(() => {
    refreshStatuses();
    const interval = setInterval(refreshStatuses, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [refreshStatuses]);

  const sendPulse = useCallback(async () => {
    setLastError(null);
    try {
      const res = await fetch(`${BACKEND_URL}/api/pulse`, { method: "POST" });
      const data: PulseResponse = await res.json();
      if (!res.ok || data.status !== "ok") {
        throw new Error(data.message || "Pulse rejected by backend");
      }
      setPulseCount(data.pulse_count ?? null);
    } catch (err) {
      setLastError(err instanceof Error ? err.message : "Failed to reach backend");
    } finally {
      // Re-check dependency health immediately after a pulse attempt.
      refreshStatuses();
    }
  }, [refreshStatuses]);

  const backendUnreachable = backendStatus === "down";

  return (
    <div className="min-h-screen w-full px-6 py-12 flex flex-col items-center gap-14">
      <header className="text-center">
        <h1 className="text-3xl font-semibold tracking-tight text-slate-50">System Pulse</h1>
        <p className="mt-2 text-sm text-slate-500">
          Frontend &rarr; Backend &rarr; Redis health &amp; tracing demo
        </p>
      </header>

      <div className="grid w-full max-w-3xl grid-cols-1 gap-4 sm:grid-cols-3">
        <StatusCard
          label="Frontend Status"
          description="Always Green"
          icon={Radio}
          status="up"
        />
        <StatusCard
          label="Backend Status"
          description="/api/health"
          icon={Server}
          status={backendStatus}
        />
        <StatusCard
          label="Database Status"
          description="/api/db-status"
          icon={Database}
          status={dbStatus}
        />
      </div>

      <div className="flex flex-col items-center gap-10 pt-6">
        <PulseButton onPulse={sendPulse} disabled={backendUnreachable} />

        <div className="mt-4 h-14 text-center">
          {pulseCount !== null && !lastError && (
            <p className="text-sm text-slate-400">
              Pulse count: <span className="font-mono text-sky-300">{pulseCount}</span>
            </p>
          )}
          {lastError && (
            <p className="max-w-xs text-sm text-red-400">
              Pulse failed: {lastError}
            </p>
          )}
          {backendUnreachable && !lastError && (
            <p className="max-w-xs text-sm text-red-400">
              Backend unreachable at {BACKEND_URL} &mdash; pulses are disabled.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
