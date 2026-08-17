'use client';
import { useEffect, useState, useCallback } from 'react';
import { api } from '../../../lib/api';
import toast from 'react-hot-toast';
import { format } from 'date-fns';

export default function PayoutsPage() {
  const [payouts, setPayouts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('REQUESTED');
  const [page, setPage] = useState(1);
  const [meta, setMeta] = useState<any>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get(`/admin/payouts?status=${tab}&page=${page}`);
      setPayouts(data.payouts); setMeta(data.meta);
    } catch { toast.error('Failed to load'); }
    setLoading(false);
  }, [tab, page]);

  useEffect(() => { load(); }, [load]);

  const doAction = async (id: string, action: 'approve' | 'reject') => {
    try {
      await api.post(`/admin/payouts/${id}/${action}`, action === 'reject' ? { reason: 'Rejected by admin' } : {});
      toast.success(`Payout ${action}d`); load();
    } catch { toast.error('Action failed'); }
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Payouts</h1>
      <div className="flex gap-2 mb-5">
        {['REQUESTED', 'APPROVED', 'REJECTED', 'PAID'].map(t => (
          <button key={t} onClick={() => { setTab(t); setPage(1); }}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition ${tab === t ? 'bg-primary text-white' : 'bg-card text-hint hover:text-white'}`}>
            {t}
          </button>
        ))}
      </div>
      <div className="bg-card border border-border rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="border-b border-border">
            <tr className="text-hint text-xs uppercase">
              <th className="text-left px-4 py-3">Listener</th>
              <th className="text-left px-4 py-3">Amount</th>
              <th className="text-left px-4 py-3">Method</th>
              <th className="text-left px-4 py-3">Status</th>
              <th className="text-left px-4 py-3">Date</th>
              <th className="text-left px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? <tr><td colSpan={6} className="text-center py-12 text-hint">Loading…</td></tr>
              : payouts.map(p => (
              <tr key={p.id} className="border-b border-border/50 hover:bg-surface/40">
                <td className="px-4 py-3 font-medium">{p.listener?.profile?.displayName ?? '—'}</td>
                <td className="px-4 py-3 text-success font-semibold">₹{Number(p.amount).toFixed(0)}</td>
                <td className="px-4 py-3 text-hint text-xs">{p.payoutMethod || '—'}</td>
                <td className="px-4 py-3">
                  <span className={`text-xs px-2 py-0.5 rounded-full ${p.status === 'APPROVED' || p.status === 'PAID' ? 'bg-success/15 text-success' : p.status === 'REJECTED' ? 'bg-error/15 text-error' : 'bg-warning/15 text-warning'}`}>{p.status}</span>
                </td>
                <td className="px-4 py-3 text-hint text-xs">{format(new Date(p.createdAt), 'dd MMM yyyy')}</td>
                <td className="px-4 py-3">
                  {p.status === 'REQUESTED' && (
                    <div className="flex gap-2">
                      <button onClick={() => doAction(p.id, 'approve')} className="text-xs bg-success/10 text-success px-3 py-1 rounded-lg hover:bg-success/20">Approve</button>
                      <button onClick={() => doAction(p.id, 'reject')} className="text-xs bg-error/10 text-error px-3 py-1 rounded-lg hover:bg-error/20">Reject</button>
                    </div>
                  )}
                </td>
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
