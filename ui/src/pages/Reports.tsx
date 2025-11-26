import { useEffect, useState } from "react";
import GlassCard from "../components/GlassCard";
import { useAuth } from "../context/AuthContext";
import { api } from "../lib/api";

export default function Reports() {
  const { token } = useAuth();
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await api.get("/reports", token || undefined);
        setData(res);
      } catch (e) { setData({ error: "Failed to fetch" }); }
    })();
  }, [token]);

  return (
    <div className="p-6 space-y-4">
      <h1 className="text-2xl font-bold">Reports</h1>
      <GlassCard>
        <pre className="text-xs overflow-auto">{JSON.stringify(data, null, 2)}</pre>
      </GlassCard>
    </div>
  );
}
