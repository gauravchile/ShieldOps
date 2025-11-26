import React, { createContext, useContext, useEffect, useState } from "react";
import { api } from "../lib/api";

type User = { id: number; username: string; role: "admin" | "analyst" | "viewer" };
type AuthCtx = {
  user: User | null;
  token: string | null;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
};

const Ctx = createContext<AuthCtx>(null!);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(localStorage.getItem("token"));
  const [user, setUser] = useState<User | null>(JSON.parse(localStorage.getItem("user") || "null"));

  useEffect(() => {
    if (token) localStorage.setItem("token", token); else localStorage.removeItem("token");
    if (user) localStorage.setItem("user", JSON.stringify(user)); else localStorage.removeItem("user");
  }, [token, user]);

  const login = async (username: string, password: string) => {
    const res = await api.post("/auth/login", { username, password });
    setToken(res.token);
    setUser(res.user);
  };

  const logout = () => { setToken(null); setUser(null); };

  return <Ctx.Provider value={{ user, token, login, logout }}>{children}</Ctx.Provider>;
}

export const useAuth = () => useContext(Ctx);
