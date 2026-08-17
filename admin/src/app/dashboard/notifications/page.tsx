'use client';
import { useState } from 'react';
import { api } from '../../../lib/api';
import toast from 'react-hot-toast';

export default function NotificationsPage() {
  const [form, setForm] = useState({ title: '', body: '', target: 'all_users', targetId: '' });
  const [sending, setSending] = useState(false);

  const send = async (e: React.FormEvent) => {
    e.preventDefault();
    setSending(true);
    try {
      const res = await api.post('/admin/notifications/broadcast', form);
      toast.success(`Sent to ${res.sent} devices`);
      setForm({ title: '', body: '', target: 'all_users', targetId: '' });
    } catch { toast.error('Failed to send'); }
    setSending(false);
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Push Notifications</h1>
      <div className="max-w-lg bg-card border border-border rounded-2xl p-6">
        <form onSubmit={send} className="space-y-4">
          <div>
            <label className="block text-xs text-muted mb-1">Target Audience</label>
            <select value={form.target} onChange={e => setForm(f => ({ ...f, target: e.target.value }))}
              className="w-full bg-surface border border-border rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-primary">
              <option value="all_users">All Users</option>
              <option value="all_listeners">All Listeners</option>
              <option value="user">Specific User</option>
              <option value="listener">Specific Listener</option>
            </select>
          </div>
          {(form.target === 'user' || form.target === 'listener') && (
            <div>
              <label className="block text-xs text-muted mb-1">User/Listener ID</label>
              <input value={form.targetId} onChange={e => setForm(f => ({ ...f, targetId: e.target.value }))}
                placeholder="Paste ID here"
                className="w-full bg-surface border border-border rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-primary" />
            </div>
          )}
          <div>
            <label className="block text-xs text-muted mb-1">Title</label>
            <input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} required
              className="w-full bg-surface border border-border rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-primary" placeholder="Notification title" />
          </div>
          <div>
            <label className="block text-xs text-muted mb-1">Message</label>
            <textarea value={form.body} onChange={e => setForm(f => ({ ...f, body: e.target.value }))} required rows={3}
              className="w-full bg-surface border border-border rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-primary resize-none" placeholder="Notification body" />
          </div>
          <button type="submit" disabled={sending}
            className="w-full bg-primary hover:bg-pink-700 disabled:opacity-50 rounded-xl py-3 font-semibold text-sm transition">
            {sending ? 'Sending…' : 'Send Notification'}
          </button>
        </form>
      </div>
    </div>
  );
}
