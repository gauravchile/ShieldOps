import { ReactNode } from "react";

export default function GlassCard({ children }: { children: ReactNode }) {
  return (
    <div className="rounded-2xl p-6 backdrop-blur-md bg-white/5 border border-cyan-400/20 shadow-xl">
      {children}
    </div>
  );
}
