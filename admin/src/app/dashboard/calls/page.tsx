'use client';
import { useEffect, useState, useCallback } from 'react';
import { api } from '../../../lib/api';
import { format } from 'date-fns';

export default function CallsPage() {
  const [calls, setCalls] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [meta, setMeta] = useState<any>(null);
  const [typeFilter, setTypeFilter] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page) });
      if (typeFilter) params.set('type', typeFilter);
      const data = await api.get(`/admin/calls?${params}`);
      setCalls(data.calls); setMeta(data.meta);
    } catch {} finally { setLoading(false); }
  }, [page, typeFilter]);

  useEffect(() => { load(); }, [load]);

  const statusColor: any = { COMPLETED: 'text-success', MISSED: 'text-warning', REJECTED: 'text-error', FAILED: 'text-error', CANCELLED: 'text-hint' };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Call Logs</h1>
      <div className="flex gap-2 mb-5">
        {['', 'AUDIO', 'VIDEO'].map(t => (
          <button key={t} onClick={() => { setTypeFilter(t); setPage(1); }}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition ${typeFilter === t ? 'bg-primary text-white' : 'bg-card text-hint hover:text-white'}`}>
            {t || 'All'}
          </button>
        ))}
      </div>
      <div className="bg-card border border-border rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="border-b border-border">
            <tr className="text-hint text-xs uppercase">
              <th className="text-left px-4 py-3">Call ID</th>
              <th className="text-left px-4 py-3">User</th>
              <th className="text-left px-4 py-3">Listener</th>
              <th className="text-left px-4 py-3">Type</th>
              <th className="text-left px-4 py-3">Duration</th>
              <th className="text-left px-4 py-3">Coins</th>
              <th className="text-left px-4 py-3">Status</th>
              <th className="text-left px-4 py-3">Date</th>
            </tr>
          </thead>
          <tbody>
            {loading ? <tr><td colSpan={8} className="text-center py-12 text-hint">Loading…</td></tr>
              : calls.map(c => (
              <tr key={c.id} className="border-b border-border/50 hover:bg-surface/40">
                <td className="px-4 py-3 font-mono text-xs text-hint">{c.id.slice(0, 8)}…</td>
                <td className="px-4 py-3">{c.user?.name ?? '—'}</td>
                <td className="px-4 py-3">{c.listener?.profile?.displayName ?? '—'}</td>
                <td className="px-4 py-3"><span className={`text-xs font-medium ${c.type === 'AUDIO' ? 'text-primary' : 'text-secondary'}`}>{c.type === 'AUDIO' ? '🎙 Audio' : '🎥 Video'}</span></td>
                <td className="px-4 py-3 text-hint">{c.durationSeconds != null ? `${Math.floor(c.durationSeconds/60)}m ${c.durationSeconds%60}s` : '—'}</td>
                <td className="px-4 py-3 text-gold">{c.billing ? Number(c.billing.coinsDeducted).toFixed(1) : '—'}</td>
                <td className={`px-4 py-3 text-xs font-medium ${statusColor[c.status] || 'text-hint'}`}>{c.status}</td>
                <td className="px-4 py-3 text-hint text-xs">{format(new Date(c.createdAt), 'dd MMM, HH:mm')}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {meta && (
          <div className="px-4 py-3 flex justify-between items-center border-t border-border text-sm text-hint">
            <span>Total: {meta.total}</span>
            <div className="flex gap-2">
              <button onClick={() => setPage(p => Math.max(1,p-1))} disabled={!meta.hasPrev} className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40">Prev</button>
              <span className="px-3 py-1">{meta.page} / {meta.totalPages}</span>
              <button onClick={() => setPage(p => p+1)} disabled={!meta.hasNext} className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40">Next</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
