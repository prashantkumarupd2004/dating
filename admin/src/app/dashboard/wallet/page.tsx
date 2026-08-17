'use client';
import { useEffect, useState, useCallback } from 'react';
import { api } from '../../../lib/api';
import toast from 'react-hot-toast';

export default function WalletPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<any>(null);
  const [coins, setCoins] = useState('');
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    try {
      const data = await api.get(`/admin/users?search=${search}&limit=20`);
      setUsers(data.users ?? []);
    } catch {}
  }, [search]);

  useEffect(() => { load(); }, [load]);

  const adjust = async () => {
    if (!selected || !coins || !reason) return;
    setLoading(true);
    try {
      await api.post(`/admin/users/${selected.id}/wallet/adjust`, { coins: Number(coins), reason });
      toast.success(`Wallet adjusted: ${coins} coins`);
      setSelected(null); setCoins(''); setReason('');
      load();
    } catch { toast.error('Failed to adjust wallet'); }
    setLoading(false);
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Wallet Management</h1>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* User search */}
        <div className="bg-card border border-border rounded-2xl p-5">
          <h2 className="font-semibold mb-4">Search User</h2>
          <input
            value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search by name, phone, email…"
            className="w-full bg-surface border border-border rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-primary mb-3"
          />
          <div className="space-y-2 max-h-80 overflow-y-auto">
            {users.map((u: any) => (
              <div
                key={u.id}
                onClick={() => setSelected(u)}
                className={`flex items-center justify-between p-3 rounded-xl cursor-pointer transition ${selected?.id === u.id ? 'bg-primary/15 border border-primary/30' : 'bg-surface hover:bg-border'}`}
              >
                <div>
                  <div className="font-medium text-sm">{u.name}</div>
                  <div className="text-xs text-hint">{u.phone || u.email}</div>
                </div>
                <div className="text-gold font-semibold text-sm">🪙 {Number(u.wallet?.balance ?? 0).toFixed(0)}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Adjust form */}
        <div className="bg-card border border-border rounded-2xl p-5">
          <h2 className="font-semibold mb-4">Adjust Coins</h2>
          {selected ? (
            <div className="space-y-4">
              <div className="bg-surface rounded-xl p-4">
                <div className="font-medium">{selected.name}</div>
                <div className="text-xs text-hint mt-1">{selected.phone || selected.email}</div>
                <div className="text-gold font-bold text-lg mt-2">🪙 {Number(selected.wallet?.balance ?? 0).toFixed(0)} coins</div>
              </div>
              <div>
                <label className="block text-xs text-muted mb-1">Coins (+ to add, - to deduct)</label>
                <input
                  type="number" value={coins} onChange={e => setCoins(e.target.value)}
                  placeholder="e.g. 100 or -50"
                  className="w-full bg-surface border border-border rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-primary"
                />
              </div>
              <div>
                <label className="block text-xs text-muted mb-1">Reason</label>
                <input
                  value={reason} onChange={e => setReason(e.target.value)}
                  placeholder="e.g. Promotional bonus, Refund…"
                  className="w-full bg-surface border border-border rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-primary"
                />
              </div>
              <div className="flex gap-3">
                <button onClick={adjust} disabled={loading || !coins || !reason}
                  className="flex-1 bg-primary hover:bg-pink-700 disabled:opacity-50 rounded-xl py-3 font-semibold text-sm transition">
                  {loading ? 'Adjusting…' : 'Apply Adjustment'}
                </button>
                <button onClick={() => setSelected(null)} className="px-4 bg-surface rounded-xl hover:bg-border transition text-sm">Cancel</button>
              </div>
            </div>
          ) : (
            <div className="flex items-center justify-center h-40 text-hint text-sm">
              Select a user from the left to adjust their wallet
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
