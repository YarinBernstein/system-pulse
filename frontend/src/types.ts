export type ServiceStatus = "checking" | "up" | "down";

export interface PulseResponse {
  status: "ok" | "error";
  pulse_count?: number;
  message?: string;
}
