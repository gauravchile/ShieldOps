import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function useAuthGuard() {
  const { token } = useAuth();
  const nav = useNavigate();
  useEffect(() => { if (!token) nav("/login"); }, [token, nav]);
}
