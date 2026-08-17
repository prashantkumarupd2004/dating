const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:5000/api';

export const apiCall = async (method: string, path: string, data?: any, token?: string) => {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: data ? JSON.stringify(data) : undefined,
    cache: 'no-store',
  });
  const json = await res.json().catch(() => ({ message: 'Server error' }));
  if (!res.ok) {
    const msg = json.message || `Request failed (${res.status})`;
    throw new Error(res.status === 401 ? `401: ${msg}` : msg);
  }
  return json.data;
};

export const getToken = () =>
  typeof window !== 'undefined' ? localStorage.getItem('admin_token') || '' : '';

export const api = {
  get: (path: string) => apiCall('GET', path, undefined, getToken()),
  post: (path: string, data?: any) => apiCall('POST', path, data, getToken()),
  patch: (path: string, data?: any) => apiCall('PATCH', path, data, getToken()),
  delete: (path: string) => apiCall('DELETE', path, undefined, getToken()),
};
