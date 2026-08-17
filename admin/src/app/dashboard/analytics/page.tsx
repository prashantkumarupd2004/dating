'use client';
import { useEffect, useState } from 'react';
import { api } from '../../../lib/api';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, BarChart, Bar } from 'recharts';

export default function AnalyticsPage() {
  const [revenue, setRevenue] = useState<any[]>([]);
  const [days, setDays] = useState(30);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    Promise.all([
      api.get(`/admin/analytics/revenue?days=${days}`),
    ]).then(([rev]) => { setRevenue(rev); }).catch(() => {}).finally(() => setLoading(false));
  }, [days]);

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Analytics</h1>
        <div className="flex gap-2">
          {[7, 30, 90].map(d => (
            <button key={d} onClick={() => setDays(d)}
              className={`px-4 py-2 rounded-xl text-sm font-medium transition ${days === d ? 'bg-primary text-white' : 'bg-card text-hint hover:text-white'}`}>
              {d}d
            </button>
          ))}
        </div>
      </div>
      {loading ? (
        <div className="flex justify-center pt-24"><div className="animate-spin w-8 h-8 border-2 border-primary border-t-transparent rounded-full" /></div>
      ) : (
        <div className="space-y-6">
          <div className="bg-card border border-border rounded-2xl p-5">
            <h2 className="font-semibold mb-4">Revenue (Coins)</h2>
            <ResponsiveContainer width="100%" height={280}>
              <LineChart data={revenue} margin={{ top: 5, right: 20, bottom: 5, left: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2A2A4A" />
                <XAxis dataKey="date" tick={{ fill: '#6B6B8A', fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                <YAxis tick={{ fill: '#6B6B8A', fontSize: 11 }} />
                <Tooltip contentStyle={{ background: '#1E1E3A', border: '1px solid #2A2A4A', borderRadius: 8 }} />
                <Legend />
                <Line type="monotone" dataKey="grossCoins" stroke="#E91E8C" strokeWidth={2} dot={false} name="Gross Coins" />
                <Line type="monotone" dataKey="platformCut" stroke="#6C63FF" strokeWidth={2} dot={false} name="Platform Cut" />
                <Line type="monotone" dataKey="listenerAmount" stroke="#43A047" strokeWidth={2} dot={false} name="Listener Earnings" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}
    </div>
  );
}
