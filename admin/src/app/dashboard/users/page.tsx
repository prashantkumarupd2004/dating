'use client';
import { useEffect, useState, useCallback } from 'react';
import { api } from '../../../lib/api';
import { Search, Shield, Ban, Coins } from 'lucide-react';
import toast from 'react-hot-toast';

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [meta, setMeta] = useState<any>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get(`/admin/users?page=${page}&search=${search}`);
      setUsers(data.users); setMeta(data.meta);
    } catch { toast.error('Failed to load users'); }
    setLoading(false);
  }, [page, search]);

  useEffect(() => { load(); }, [load]);

  const action = async (userId: string, endpoint: string, label: string) => {
    try {
      await api.post(`/admin/users/${userId}/${endpoint}`, {});
      toast.success(`${label} successful`); load();
    } catch { toast.error(`${label} failed`); }
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Users</h1>
      <div className="flex gap-3 mb-5">
        <div className="relative flex-1 max-w-sm">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-hint" />
          <input value={search} onChange={e => { setSearch(e.target.value); setPage(1); }}
            placeholder="Search by name, phone, email…"
            className="w-full bg-card border border-border rounded-xl pl-9 pr-4 py-2.5 text-sm focus:outline-none focus:border-primary" />
        </div>
      </div>
      <div className="bg-card border border-border rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="border-b border-border">
            <tr className="text-hint text-xs uppercase">
              <th className="text-left px-4 py-3">User</th>
              <th className="text-left px-4 py-3">Contact</th>
              <th className="text-left px-4 py-3">Balance</th>
              <th className="text-left px-4 py-3">Status</th>
              <th className="text-left px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={5} className="text-center py-12 text-hint">Loading…</td></tr>
            ) : users.map(u => (
              <tr key={u.id} className="border-b border-border/50 hover:bg-surface/40 transition">
                <td className="px-4 py-3">
                  <div className="font-medium">{u.name}</div>
                  <div className="text-xs text-hint">{u.id.slice(0, 8)}…</div>
                </td>
                <td className="px-4 py-3 text-hint">{u.phone || u.email || '—'}</td>
                <td className="px-4 py-3">
                  <span className="text-gold font-semibold">🪙 {Number(u.wallet?.balance ?? 0).toFixed(0)}</span>
                </td>
                <td className="px-4 py-3">
                  {u.isBanned ? <span className="text-xs bg-error/15 text-error px-2 py-1 rounded-full">Banned</span>
                  : u.isSuspended ? <span className="text-xs bg-warning/15 text-warning px-2 py-1 rounded-full">Suspended</span>
                  : <span className="text-xs bg-success/15 text-success px-2 py-1 rounded-full">Active</span>}
                </td>
                <td className="px-4 py-3">
                  <div className="flex gap-2">
                    {u.isBanned
                      ? <button onClick={() => action(u.id, 'unban', 'Unban')} className="text-xs bg-success/10 text-success px-3 py-1 rounded-lg hover:bg-success/20 transition">Unban</button>
                      : <button onClick={() => action(u.id, 'ban', 'Ban')} className="text-xs bg-error/10 text-error px-3 py-1 rounded-lg hover:bg-error/20 transition">Ban</button>
                    }
                    <button onClick={() => action(u.id, 'suspend', 'Suspend')} className="text-xs bg-warning/10 text-warning px-3 py-1 rounded-lg hover:bg-warning/20 transition">Suspend</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {meta && (
          <div className="px-4 py-3 flex justify-between items-center border-t border-border text-sm text-hint">
            <span>Total: {meta.total}</span>
            <div className="flex gap-2">
              <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={!meta.hasPrev} className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40 hover:bg-border transition">Prev</button>
              <span className="px-3 py-1">{meta.page} / {meta.totalPages}</span>
              <button onClick={() => setPage(p => p + 1)} disabled={!meta.hasNext} className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40 hover:bg-border transition">Next</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
