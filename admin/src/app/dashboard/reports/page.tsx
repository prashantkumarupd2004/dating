'use client';
import { useEffect, useState, useCallback } from 'react';
import { api } from '../../../lib/api';
import toast from 'react-hot-toast';
import { format } from 'date-fns';

export default function ReportsPage() {
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('OPEN');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get(`/admin/reports?status=${tab}`);
      setReports(data.reports);
    } catch {} finally { setLoading(false); }
  }, [tab]);

  useEffect(() => { load(); }, [load]);

  const resolve = async (id: string, status: string) => {
    try {
      await api.patch(`/admin/reports/${id}`, { status });
      toast.success('Report updated'); load();
    } catch { toast.error('Failed'); }
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Reports</h1>
      <div className="flex gap-2 mb-5">
        {['OPEN', 'INVESTIGATING', 'RESOLVED', 'REJECTED'].map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition ${tab === t ? 'bg-primary text-white' : 'bg-card text-hint hover:text-white'}`}>{t}</button>
        ))}
      </div>
      <div className="bg-card border border-border rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="border-b border-border">
            <tr className="text-hint text-xs uppercase">
              <th className="text-left px-4 py-3">Reporter</th>
              <th className="text-left px-4 py-3">Reported</th>
              <th className="text-left px-4 py-3">Category</th>
              <th className="text-left px-4 py-3">Description</th>
              <th className="text-left px-4 py-3">Date</th>
              <th className="text-left px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? <tr><td colSpan={6} className="text-center py-12 text-hint">Loading…</td></tr>
              : reports.map(r => (
              <tr key={r.id} className="border-b border-border/50 hover:bg-surface/40">
                <td className="px-4 py-3 font-medium">{r.reporter?.name ?? '—'}</td>
                <td className="px-4 py-3 text-hint">{r.reportedUser?.name || r.reportedListener?.profile?.displayName || '—'}</td>
                <td className="px-4 py-3"><span className="text-xs bg-error/10 text-error px-2 py-0.5 rounded-full">{r.category?.replace(/_/g, ' ')}</span></td>
                <td className="px-4 py-3 text-hint text-xs max-w-xs truncate">{r.description || '—'}</td>
                <td className="px-4 py-3 text-hint text-xs">{format(new Date(r.createdAt), 'dd MMM')}</td>
                <td className="px-4 py-3">
                  {r.status === 'OPEN' && (
                    <div className="flex gap-2">
                      <button onClick={() => resolve(r.id, 'INVESTIGATING')} className="text-xs bg-warning/10 text-warning px-2 py-1 rounded-lg hover:bg-warning/20">Investigate</button>
                      <button onClick={() => resolve(r.id, 'RESOLVED')} className="text-xs bg-success/10 text-success px-2 py-1 rounded-lg hover:bg-success/20">Resolve</button>
                    </div>
                  )}
                  {r.status === 'INVESTIGATING' && (
                    <button onClick={() => resolve(r.id, 'RESOLVED')} className="text-xs bg-success/10 text-success px-2 py-1 rounded-lg hover:bg-success/20">Resolve</button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
