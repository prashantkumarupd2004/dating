'use client';
import { useEffect, useState, useCallback } from 'react';
import { api } from '../../../lib/api';
import { format } from 'date-fns';

export default function PaymentsPage() {
  const [payments, setPayments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const LIMIT = 20;

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get(`/admin/payments?page=${page}&limit=${LIMIT}`);
      setPayments(data.payments ?? data); setTotal(data.total ?? data.length ?? 0);
    } catch {} finally { setLoading(false); }
  }, [page]);

  useEffect(() => { load(); }, [load]);

  const statusColor: Record<string, string> = {
    SUCCESS: 'bg-success/15 text-success',
    PENDING: 'bg-warning/15 text-warning',
    FAILED: 'bg-error/15 text-error',
    REFUNDED: 'bg-hint/15 text-hint',
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Payment Transactions</h1>
      <div className="bg-card border border-border rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="border-b border-border">
            <tr className="text-hint text-xs uppercase">
              <th className="text-left px-4 py-3">Order ID</th>
              <th className="text-left px-4 py-3">User</th>
              <th className="text-left px-4 py-3">Amount</th>
              <th className="text-left px-4 py-3">Coins</th>
              <th className="text-left px-4 py-3">Bonus</th>
              <th className="text-left px-4 py-3">Status</th>
              <th className="text-left px-4 py-3">Date</th>
            </tr>
          </thead>
          <tbody>
            {loading
              ? <tr><td colSpan={7} className="text-center py-12 text-hint">Loading…</td></tr>
              : payments.map((p: any) => (
              <tr key={p.id} className="border-b border-border/50 hover:bg-surface/40">
                <td className="px-4 py-3 font-mono text-xs text-hint">{(p.razorpayOrderId ?? '').slice(0, 16)}…</td>
                <td className="px-4 py-3 font-medium">{p.user?.name ?? '—'}</td>
                <td className="px-4 py-3 font-semibold">₹{Number(p.amount).toFixed(0)}</td>
                <td className="px-4 py-3 text-gold font-semibold">🪙 {p.coins}</td>
                <td className="px-4 py-3 text-success text-xs">{p.bonusCoins > 0 ? `+${p.bonusCoins}` : '—'}</td>
                <td className="px-4 py-3">
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColor[p.status] ?? ''}`}>{p.status}</span>
                </td>
                <td className="px-4 py-3 text-hint text-xs">{format(new Date(p.createdAt), 'dd MMM, HH:mm')}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <div className="px-4 py-3 flex justify-between items-center border-t border-border text-sm text-hint">
          <span>Total: {total}</span>
          <div className="flex gap-2">
            <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40">Prev</button>
            <span className="px-3 py-1">{page} / {Math.ceil(total / LIMIT) || 1}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={page >= Math.ceil(total / LIMIT)} className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40">Next</button>
          </div>
        </div>
      </div>
    </div>
  );
}
