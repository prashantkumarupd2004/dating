'use client';
import { useEffect, useState, useCallback } from 'react';
import { api } from '../../../lib/api';
import toast from 'react-hot-toast';
import { format } from 'date-fns';

export default function SupportPage() {
  const [tickets, setTickets] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('OPEN');
  const [selected, setSelected] = useState<any>(null);
  const [reply, setReply] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.get(`/admin/support/tickets?status=${tab}`);
      setTickets(data.tickets);
    } catch {} finally { setLoading(false); }
  }, [tab]);

  useEffect(() => { load(); }, [load]);

  const sendReply = async () => {
    if (!reply.trim() || !selected) return;
    try {
      await api.post(`/admin/support/tickets/${selected.id}/reply`, { message: reply, status: 'IN_PROGRESS' });
      toast.success('Reply sent');
      setReply('');
      load();
    } catch { toast.error('Failed'); }
  };

  const close = async (id: string) => {
    try {
      await api.patch(`/admin/support/tickets/${id}/status`, { status: 'RESOLVED' });
      toast.success('Ticket resolved'); load(); setSelected(null);
    } catch { toast.error('Failed'); }
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Support Tickets</h1>
      <div className="flex gap-2 mb-5">
        {['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'].map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition ${tab === t ? 'bg-primary text-white' : 'bg-card text-hint hover:text-white'}`}>{t.replace('_', ' ')}</button>
        ))}
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-1 bg-card border border-border rounded-2xl overflow-hidden">
          {loading ? <div className="text-center py-12 text-hint text-sm">Loading…</div>
            : tickets.length === 0 ? <div className="text-center py-12 text-hint text-sm">No tickets</div>
            : tickets.map(t => (
            <div key={t.id} onClick={() => setSelected(t)}
              className={`p-4 border-b border-border/50 cursor-pointer hover:bg-surface/40 transition ${selected?.id === t.id ? 'bg-primary/10 border-l-2 border-l-primary' : ''}`}>
              <div className="font-medium text-sm">{t.subject}</div>
              <div className="text-xs text-hint mt-1">{t.user?.name} · {format(new Date(t.createdAt), 'dd MMM')}</div>
            </div>
          ))}
        </div>
        {selected && (
          <div className="lg:col-span-2 bg-card border border-border rounded-2xl p-5 flex flex-col gap-4">
            <div className="flex justify-between items-start">
              <div>
                <div className="font-semibold">{selected.subject}</div>
                <div className="text-xs text-hint mt-1">From: {selected.user?.name}</div>
              </div>
              <button onClick={() => close(selected.id)} className="text-xs bg-success/10 text-success px-3 py-1.5 rounded-lg hover:bg-success/20">Resolve</button>
            </div>
            <div className="flex-1 space-y-3 max-h-80 overflow-y-auto">
              {(selected.replies || []).map((r: any) => (
                <div key={r.id} className={`max-w-xs p-3 rounded-xl text-sm ${r.isAdmin ? 'ml-auto bg-primary/20 text-right' : 'bg-surface'}`}>
                  <div>{r.message}</div>
                  <div className="text-xs text-hint mt-1">{format(new Date(r.createdAt), 'HH:mm')}</div>
                </div>
              ))}
            </div>
            <div className="flex gap-2">
              <input value={reply} onChange={e => setReply(e.target.value)} placeholder="Type a reply…"
                className="flex-1 bg-surface border border-border rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-primary"
                onKeyDown={e => e.key === 'Enter' && sendReply()} />
              <button onClick={sendReply} className="bg-primary px-4 py-2.5 rounded-xl text-sm font-semibold hover:bg-pink-700 transition">Send</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
