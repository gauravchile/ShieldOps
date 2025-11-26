const BASE = import.meta.env.VITE_API_BASE_URL || "http://localhost:8081/api";

async function request(path: string, method = "GET", body?: any, token?: string) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export const api = {
  get: (p: string, t?: string) => request(p, "GET", undefined, t),
  post: (p: string, b?: any, t?: string) => request(p, "POST", b, t),
};
