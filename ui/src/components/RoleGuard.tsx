import { ReactNode } from "react";
import { useAuth } from "../context/AuthContext";

export default function RoleGuard({ roles, children }:
  { roles: string[]; children: ReactNode }) {
  const { user } = useAuth();
  if (!user || !roles.includes(user.role)) {
    return <div className="p-6">⛔ Forbidden</div>;
  }
  return <>{children}</>;
}
