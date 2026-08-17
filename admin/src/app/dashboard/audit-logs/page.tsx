'use client';
import { useEffect, useState } from 'react';
import { api } from '../../../lib/api';
import { format } from 'date-fns';

export default function AuditLogsPage() {
  const [logs, setLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const LIMIT = 50;

  useEffect(() => {
    setLoading(true);
    api.get(`/admin/audit-logs?page=${page}`)
      .then(data => { setLogs(data.logs); setTotal(data.total); })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [page]);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Audit Logs</h1>
      <div className="bg-card border border-border rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="border-b border-border">
            <tr className="text-hint text-xs uppercase">
              <th className="text-left px-4 py-3">Admin</th>
              <th className="text-left px-4 py-3">Action</th>
              <th className="text-left px-4 py-3">Target</th>
              <th className="text-left px-4 py-3">Change</th>
              <th className="text-left px-4 py-3">Date</th>
            </tr>
          </thead>
          <tbody>
            {loading ? <tr><td colSpan={5} className="text-center py-12 text-hint">Loading…</td></tr>
              : logs.map(l => (
              <tr key={l.id} className="border-b border-border/50 hover:bg-surface/40">
                <td className="px-4 py-3 font-medium text-xs">{l.admin?.name ?? '—'}</td>
                <td className="px-4 py-3"><span className="text-xs bg-primary/10 text-primary px-2 py-0.5 rounded-full font-mono">{l.action}</span></td>
                <td className="px-4 py-3 text-hint text-xs">{l.targetType} {l.targetId ? `· ${l.targetId.slice(0,8)}…` : ''}</td>
                <td className="px-4 py-3 text-xs text-hint max-w-xs">
                  {l.newValue ? <code className="bg-surface px-2 py-0.5 rounded text-xs">{JSON.stringify(l.newValue).slice(0, 60)}</code> : '—'}
                </td>
                <td className="px-4 py-3 text-hint text-xs">{format(new Date(l.createdAt), 'dd MMM, HH:mm')}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <div className="px-4 py-3 flex justify-between items-center border-t border-border text-sm text-hint">
          <span>Total: {total}</span>
          <div className="flex gap-2">
            <button onClick={() => setPage(p => Math.max(1,p-1))} disabled={page===1} className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40">Prev</button>
            <span className="px-3 py-1">{page} / {Math.ceil(total/LIMIT) || 1}</span>
            <button onClick={() => setPage(p => p+1)} disabled={page>=Math.ceil(total/LIMIT)} className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40">Next</button>
          </div>
        </div>
      </div>
    </div>
  );
}
