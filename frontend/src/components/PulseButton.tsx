import { useState } from "react";
import { Activity, Loader2 } from "lucide-react";

interface PulseButtonProps {
  onPulse: () => Promise<void>;
  disabled: boolean;
}

export function PulseButton({ onPulse, disabled }: PulseButtonProps) {
  const [isPulsing, setIsPulsing] = useState(false);
  const [showRing, setShowRing] = useState(false);

  const handleClick = async () => {
    if (isPulsing || disabled) return;
    setIsPulsing(true);
    setShowRing(true);
    try {
      await onPulse();
    } finally {
      setIsPulsing(false);
      window.setTimeout(() => setShowRing(false), 1100);
    }
  };

  return (
    <button
      onClick={handleClick}
      disabled={disabled || isPulsing}
      className={`relative flex h-40 w-40 items-center justify-center rounded-full
        bg-gradient-to-br from-sky-500 to-indigo-600 text-white shadow-lg shadow-sky-950/40
        transition-transform duration-150 ease-out
        hover:scale-105 active:scale-95
        disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:scale-100
        ${showRing ? "pulse-ring" : ""}`}
    >
      {isPulsing ? (
        <Loader2 className="h-10 w-10 animate-spin" strokeWidth={1.5} />
      ) : (
        <Activity className="h-10 w-10" strokeWidth={1.5} />
      )}
      <span className="absolute -bottom-9 text-sm font-medium tracking-wide text-slate-300">
        Send Pulse
      </span>
    </button>
  );
}
