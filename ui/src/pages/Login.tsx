import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import GlassCard from "../components/GlassCard";
import NeonText from "../components/NeonText";

export default function Login() {
  const [username, setU] = useState("admin");
  const [password, setP] = useState("shieldops");
  const [error, setError] = useState<string | null>(null);
  const { login } = useAuth();
  const nav = useNavigate();

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await login(username, password);
      nav("/");
    } catch (e: any) {
      setError(e.message || "Login failed");
    }
  };

  return (
    <div className="min-h-screen grid place-items-center p-6">
      <GlassCard>
        <form onSubmit={onSubmit} className="w-80 space-y-4">
          <h1 className="text-2xl font-semibold text-center"><NeonText>ShieldOps</NeonText></h1>
          {error && <div className="text-red-400 text-sm">{error}</div>}
          <div className="space-y-1">
            <label className="text-sm text-slate-300">Username</label>
            <input className="w-full px-3 py-2 rounded-lg bg-black/40 border border-cyan-400/30"
              value={username} onChange={e => setU(e.target.value)} />
          </div>
          <div className="space-y-1">
            <label className="text-sm text-slate-300">Password</label>
            <input type="password" className="w-full px-3 py-2 rounded-lg bg-black/40 border border-cyan-400/30"
              value={password} onChange={e => setP(e.target.value)} />
          </div>
          <button className="w-full py-2 rounded-lg border border-cyan-400/50 hover:bg-cyan-400/10">Login</button>
        </form>
      </GlassCard>
    </div>
  );
}
