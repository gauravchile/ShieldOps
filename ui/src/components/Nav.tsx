import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import NeonText from "./NeonText";

export default function Nav() {
  const { user, logout } = useAuth();
  const nav = useNavigate();
  return (
    <nav className="flex items-center justify-between px-6 py-4 bg-black/40 border-b border-cyan-400/20 sticky top-0 backdrop-blur">
      <Link to="/" className="text-xl">
        <NeonText>ShieldOps</NeonText>
      </Link>
      <div className="flex items-center gap-4">
        <Link to="/" className="hover:text-cyan-300">Dashboard</Link>
        <Link to="/reports" className="hover:text-cyan-300">Reports</Link>
        <span className="text-sm text-slate-400">({user?.role})</span>
        <button
          onClick={() => { logout(); nav("/login"); }}
          className="px-3 py-1 rounded-lg border border-cyan-400/40 hover:bg-cyan-400/10"
        >
          Logout
        </button>
      </div>
    </nav>
  );
}
