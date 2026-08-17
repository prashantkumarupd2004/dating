'use client';
import { useEffect, useState } from 'react';
import { api } from '../../lib/api';
import { Users, Headphones, Phone, DollarSign, AlertTriangle, Clock, Wifi, TrendingUp } from 'lucide-react';

interface Stats {
  totalUsers: number; totalListeners: number; onlineListeners: number;
  todayCalls: number; todayAudio: number; todayVideo: number;
  pendingApprovals: number; openReports: number; pendingPayouts: number;
  todayRevenue: { grossCoins: number; platformCut: number; listenerEarnings: number };
}

function StatCard({ icon: Icon, label, value, color }: any) {
  return (
    <div className="bg-card border border-border rounded-2xl p-5">
      <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-3 ${color}`}>
        <Icon size={20} className="text-white" />
      </div>
      <div className="text-2xl font-bold">{value ?? '—'}</div>
      <div className="text-xs text-hint mt-1">{label}</div>
    </div>
  );
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = () => {
    setLoading(true);
    setError(null);
    api.get('/admin/dashboard')
      .then(setStats)
      .catch((e: any) => {
        const msg = e?.message || 'Failed to load dashboard';
        setError(msg.includes('401') || msg.toLowerCase().includes('unauthorized')
          ? 'Session expired. Please login again.'
          : msg);
      })
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  if (loading) return <div className="flex items-center justify-center h-64"><div className="animate-spin w-8 h-8 border-2 border-primary border-t-transparent rounded-full" /></div>;
  if (error) return (
    <div className="flex flex-col items-center justify-center h-64 gap-4">
      <div className="text-red-400 text-center">
        <div className="text-lg font-semibold mb-1">⚠️ {error}</div>
        <div className="text-sm text-hint">Check if the backend server is running</div>
      </div>
      <button onClick={load} className="px-4 py-2 bg-primary text-white rounded-xl text-sm hover:bg-primary/80 transition">
        🔄 Retry
      </button>
      {error.includes('Session') && (
        <a href="/login" className="text-xs text-hint underline">Go to Login</a>
      )}
    </div>
  );

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Dashboard</h1>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <StatCard icon={Users} label="Total Users" value={stats?.totalUsers?.toLocaleString()} color="bg-blue-600" />
        <StatCard icon={Headphones} label="Listeners" value={stats?.totalListeners?.toLocaleString()} color="bg-purple-600" />
        <StatCard icon={Wifi} label="Online Now" value={stats?.onlineListeners} color="bg-green-600" />
        <StatCard icon={Phone} label="Today's Calls" value={stats?.todayCalls} color="bg-primary" />
        <StatCard icon={TrendingUp} label="Platform Revenue" value={`${Number(stats?.todayRevenue?.platformCut ?? 0).toFixed(0)} coins`} color="bg-yellow-600" />
        <StatCard icon={Clock} label="Pending Approvals" value={stats?.pendingApprovals} color="bg-orange-600" />
        <StatCard icon={AlertTriangle} label="Open Reports" value={stats?.openReports} color="bg-red-600" />
        <StatCard icon={DollarSign} label="Pending Payouts" value={stats?.pendingPayouts} color="bg-teal-600" />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-card border border-border rounded-2xl p-5">
          <h2 className="font-semibold mb-4">Today's Calls</h2>
          <div className="flex gap-8">
            <div><div className="text-3xl font-bold text-primary">{stats?.todayAudio ?? 0}</div><div className="text-xs text-hint mt-1">🎙 Audio Calls</div></div>
            <div><div className="text-3xl font-bold text-secondary">{stats?.todayVideo ?? 0}</div><div className="text-xs text-hint mt-1">🎥 Video Calls</div></div>
          </div>
        </div>
        <div className="bg-card border border-border rounded-2xl p-5">
          <h2 className="font-semibold mb-4">Today's Revenue</h2>
          <div className="space-y-3">
            <div className="flex justify-between text-sm"><span className="text-hint">Gross Coins</span><span className="font-semibold">{Number(stats?.todayRevenue?.grossCoins ?? 0).toFixed(1)}</span></div>
            <div className="flex justify-between text-sm"><span className="text-hint">Platform Cut</span><span className="font-semibold text-success">{Number(stats?.todayRevenue?.platformCut ?? 0).toFixed(1)}</span></div>
            <div className="flex justify-between text-sm"><span className="text-hint">Listener Earnings</span><span className="font-semibold text-primary">₹{Number(stats?.todayRevenue?.listenerEarnings ?? 0).toFixed(0)}</span></div>
          </div>
        </div>
      </div>
    </div>
  );
}
