import { ReactNode } from "react";

export default function NeonText({ children }: { children: ReactNode }) {
  return (
    <span className="text-cyan-300 drop-shadow-[0_0_10px_rgba(34,211,238,0.7)]">
      {children}
    </span>
  );
}
