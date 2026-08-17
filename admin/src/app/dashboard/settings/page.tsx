'use client';
import { useEffect, useState } from 'react';
import { api } from '../../../lib/api';
import toast from 'react-hot-toast';

export default function SettingsPage() {
  const [settings, setSettings] = useState<Record<string, any[]>>({});
  const [editing, setEditing] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/admin/settings').then(data => { setSettings(data); setLoading(false); }).catch(() => setLoading(false));
  }, []);

  const save = async (key: string) => {
    try {
      await api.patch(`/admin/settings/${key}`, { value: editing[key] });
      toast.success('Setting updated');
      setSettings(prev => {
        const next = { ...prev };
        for (const group of Object.keys(next)) {
          next[group] = next[group].map(s => s.key === key ? { ...s, value: editing[key] } : s);
        }
        return next;
      });
      setEditing(prev => { const n = { ...prev }; delete n[key]; return n; });
    } catch { toast.error('Failed to update'); }
  };

  if (loading) return <div className="flex justify-center pt-24"><div className="animate-spin w-8 h-8 border-2 border-primary border-t-transparent rounded-full" /></div>;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Settings</h1>
      <div className="space-y-6">
        {Object.entries(settings).map(([group, items]) => (
          <div key={group} className="bg-card border border-border rounded-2xl overflow-hidden">
            <div className="px-5 py-3 border-b border-border bg-surface/40">
              <h2 className="font-semibold capitalize text-sm">{group}</h2>
            </div>
            <div className="divide-y divide-border/50">
              {items.map((s: any) => (
                <div key={s.key} className="px-5 py-4 flex items-center gap-4">
                  <div className="flex-1">
                    <div className="font-medium text-sm">{s.key.replace(/_/g, ' ')}</div>
                    {s.description && <div className="text-xs text-hint mt-0.5">{s.description}</div>}
                  </div>
                  <div className="flex items-center gap-2">
                    <input
                      value={editing[s.key] ?? s.value}
                      onChange={e => setEditing(prev => ({ ...prev, [s.key]: e.target.value }))}
                      className="bg-surface border border-border rounded-xl px-3 py-2 text-sm w-32 focus:outline-none focus:border-primary"
                    />
                    {editing[s.key] !== undefined && editing[s.key] !== s.value && (
                      <button onClick={() => save(s.key)} className="px-3 py-2 bg-primary rounded-xl text-xs font-semibold hover:bg-pink-700 transition">Save</button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
