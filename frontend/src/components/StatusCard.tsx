import type { LucideIcon } from "lucide-react";
import { CheckCircle2, XCircle, Loader2 } from "lucide-react";
import type { ServiceStatus } from "../types";

interface StatusCardProps {
  label: string;
  description: string;
  icon: LucideIcon;
  status: ServiceStatus;
}

const STATUS_STYLES: Record<
  ServiceStatus,
  { text: string; dot: string; ring: string; badge: string }
> = {
  checking: {
    text: "Checking...",
    dot: "bg-amber-400",
    ring: "ring-amber-400/30",
    badge: "text-amber-300 bg-amber-400/10",
  },
  up: {
    text: "Connected",
    dot: "bg-emerald-400",
    ring: "ring-emerald-400/30",
    badge: "text-emerald-300 bg-emerald-400/10",
  },
  down: {
    text: "Disconnected",
    dot: "bg-red-500",
    ring: "ring-red-500/30",
    badge: "text-red-300 bg-red-500/10",
  },
};

export function StatusCard({ label, description, icon: Icon, status }: StatusCardProps) {
  const style = STATUS_STYLES[status];

  return (
    <div className={`glass rounded-2xl p-5 flex flex-col gap-4 ring-1 ${style.ring} transition-all duration-300`}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="rounded-xl bg-white/5 p-2.5">
            <Icon className="h-5 w-5 text-slate-300" strokeWidth={1.75} />
          </div>
          <div>
            <p className="text-sm font-medium text-slate-100">{label}</p>
            <p className="text-xs text-slate-500">{description}</p>
          </div>
        </div>
        {status === "checking" ? (
          <Loader2 className="h-4 w-4 animate-spin text-amber-300" />
        ) : status === "up" ? (
          <CheckCircle2 className="h-4 w-4 text-emerald-400" />
        ) : (
          <XCircle className="h-4 w-4 text-red-500" />
        )}
      </div>

      <div className={`inline-flex w-fit items-center gap-2 rounded-full px-3 py-1 text-xs font-medium ${style.badge}`}>
        <span className={`h-1.5 w-1.5 rounded-full ${style.dot}`} />
        {style.text}
      </div>
    </div>
  );
}
