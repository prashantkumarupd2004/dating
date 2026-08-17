'use client';
import { useEffect, useState } from 'react';
import { api } from '../../../lib/api';
import toast from 'react-hot-toast';
import { Plus, Pencil, Trash2, Flame, Star, Tag } from 'lucide-react';

interface Pkg {
  id: string;
  name: string;
  coins: number;
  bonusCoins: number;
  priceInr: string;
  originalPriceInr: string | null;
  badge: string | null;
  isActive: boolean;
  sortOrder: number;
}

const empty: Partial<Pkg> = {
  name: '',
  coins: 0,
  bonusCoins: 0,
  priceInr: '',
  originalPriceInr: '',
  badge: '',
  sortOrder: 0,
  isActive: true,
};

const BADGES = ['', 'Hot', 'Value Pack', 'Popular', 'Best Deal'];

function BadgePill({ badge }: { badge: string | null }) {
  if (!badge) return null;
  const isHot = badge.toLowerCase() === 'hot';
  const isValue = badge.toLowerCase() === 'value pack';
  return (
    <span
      className={`inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full font-semibold ${
        isHot ? 'bg-orange-500/20 text-orange-400' : isValue ? 'bg-purple-500/20 text-purple-400' : 'bg-blue-500/20 text-blue-400'
      }`}
    >
      {isHot && <Flame size={10} />}
      {isValue && <Star size={10} />}
      {!isHot && !isValue && <Tag size={10} />}
      {badge}
    </span>
  );
}

export default function CoinPackagesPage() {
  const [packages, setPackages] = useState<Pkg[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState<any>(empty);
  const [editing, setEditing] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);

  const load = async () => {
    setLoading(true);
    api.get('/admin/coin-packages').then(setPackages).catch(() => {}).finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const payload = {
      ...form,
      coins: Number(form.coins),
      bonusCoins: Number(form.bonusCoins),
      sortOrder: Number(form.sortOrder),
      originalPriceInr: form.originalPriceInr && form.originalPriceInr !== '' ? Number(form.originalPriceInr) : null,
      badge: form.badge && form.badge !== '' ? form.badge : null,
    };
    try {
      if (editing) {
        await api.patch(`/admin/coin-packages/${editing}`, payload);
        toast.success('Package updated');
      } else {
        await api.post('/admin/coin-packages', payload);
        toast.success('Package created');
      }
      setShowForm(false); setEditing(null); setForm(empty); load();
    } catch { toast.error('Failed'); }
  };

  const remove = async (id: string) => {
    try { await api.delete(`/admin/coin-packages/${id}`); toast.success('Package deactivated'); load(); } catch { toast.error('Failed'); }
  };

  const editPkg = (p: Pkg) => {
    setForm({
      name: p.name,
      coins: p.coins,
      bonusCoins: p.bonusCoins,
      priceInr: p.priceInr,
      originalPriceInr: p.originalPriceInr ?? '',
      badge: p.badge ?? '',
      sortOrder: p.sortOrder,
      isActive: p.isActive,
    });
    setEditing(p.id);
    setShowForm(true);
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-2xl font-bold">Coin Packages</h1>
          <p className="text-sm text-muted mt-1">Manage recharge packages shown in the app</p>
        </div>
        <button
          onClick={() => { setForm(empty); setEditing(null); setShowForm(true); }}
          className="flex items-center gap-2 bg-primary px-4 py-2 rounded-xl text-sm font-semibold hover:bg-pink-700 transition"
        >
          <Plus size={16} /> New Package
        </button>
      </div>

      {showForm && (
        <form onSubmit={submit} className="bg-card border border-border rounded-2xl p-5 mb-6">
          <h2 className="font-semibold mb-4 text-sm">{editing ? 'Edit Package' : 'Create New Package'}</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              ['name', 'Package Name', 'text'],
              ['coins', 'Coins', 'number'],
              ['bonusCoins', 'Bonus Coins', 'number'],
              ['priceInr', 'Price (₹)', 'number'],
              ['originalPriceInr', 'Original Price (₹) — for strikethrough', 'number'],
              ['sortOrder', 'Sort Order', 'number'],
            ].map(([key, label, type]) => (
              <div key={key as string} className={key === 'name' ? 'col-span-2' : ''}>
                <label className="block text-xs text-muted mb-1">{label as string}</label>
                <input
                  type={type as string}
                  placeholder={key === 'originalPriceInr' ? 'Leave blank if no discount' : ''}
                  value={form[key as string] ?? ''}
                  onChange={e => setForm((f: any) => ({ ...f, [key as string]: e.target.value }))}
                  className="w-full bg-surface border border-border rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary"
                  required={key !== 'originalPriceInr' && key !== 'bonusCoins'}
                />
              </div>
            ))}
            {/* Badge dropdown */}
            <div>
              <label className="block text-xs text-muted mb-1">Badge (optional)</label>
              <select
                value={form.badge ?? ''}
                onChange={e => setForm((f: any) => ({ ...f, badge: e.target.value }))}
                className="w-full bg-surface border border-border rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary"
              >
                {BADGES.map(b => <option key={b} value={b}>{b || '— None —'}</option>)}
              </select>
            </div>
            {/* Active toggle */}
            <div className="flex items-end pb-1">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={form.isActive}
                  onChange={e => setForm((f: any) => ({ ...f, isActive: e.target.checked }))}
                  className="w-4 h-4 accent-primary"
                />
                <span className="text-sm">Active</span>
              </label>
            </div>
          </div>
          <div className="flex gap-2 mt-4">
            <button type="submit" className="bg-primary rounded-xl px-6 py-2.5 text-sm font-semibold hover:bg-pink-700 transition">
              {editing ? 'Update Package' : 'Create Package'}
            </button>
            <button type="button" onClick={() => { setShowForm(false); setEditing(null); }} className="bg-surface rounded-xl px-6 py-2.5 text-sm hover:bg-border transition">
              Cancel
            </button>
          </div>
        </form>
      )}

      {/* Package preview cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3 mb-6">
        {packages.filter(p => p.isActive).map(p => {
          const hasDiscount = p.originalPriceInr && Number(p.originalPriceInr) > Number(p.priceInr);
          return (
            <div key={p.id} className="bg-[#1a1a1a] border border-border rounded-2xl p-3 text-center relative">
              {p.badge && (
                <div className="absolute -top-2 left-1/2 -translate-x-1/2">
                  <BadgePill badge={p.badge} />
                </div>
              )}
              <div className="text-3xl mt-2">🪙</div>
              <div className="text-white font-bold text-lg mt-1">{p.coins.toLocaleString()}</div>
              {p.bonusCoins > 0 && (
                <div className="text-purple-400 text-xs font-semibold">+{p.bonusCoins.toLocaleString()} 🪙</div>
              )}
              <div className="mt-2">
                {hasDiscount && (
                  <div className="text-white/40 text-xs line-through">₹{Number(p.originalPriceInr).toFixed(0)}</div>
                )}
                <div className="text-white font-bold">₹{Number(p.priceInr).toFixed(0)}</div>
                {hasDiscount && (
                  <div className="text-purple-400 text-xs">Flat ₹{(Number(p.originalPriceInr) - Number(p.priceInr)).toFixed(0)} off</div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Table */}
      <div className="bg-card border border-border rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="border-b border-border">
            <tr className="text-hint text-xs uppercase">
              <th className="text-left px-4 py-3">Package</th>
              <th className="text-left px-4 py-3">Coins</th>
              <th className="text-left px-4 py-3">Bonus</th>
              <th className="text-left px-4 py-3">Price</th>
              <th className="text-left px-4 py-3">Orig. Price</th>
              <th className="text-left px-4 py-3">Badge</th>
              <th className="text-left px-4 py-3">Order</th>
              <th className="text-left px-4 py-3">Status</th>
              <th className="text-left px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={9} className="text-center py-12 text-hint">Loading…</td></tr>
            ) : packages.map(p => (
              <tr key={p.id} className="border-b border-border/50 hover:bg-surface/40">
                <td className="px-4 py-3 font-medium">{p.name}</td>
                <td className="px-4 py-3 text-yellow-400 font-semibold">🪙 {p.coins.toLocaleString()}</td>
                <td className="px-4 py-3 text-green-400 text-xs">{p.bonusCoins > 0 ? `+${p.bonusCoins}` : '—'}</td>
                <td className="px-4 py-3 font-semibold">₹{Number(p.priceInr).toFixed(0)}</td>
                <td className="px-4 py-3 text-hint line-through text-xs">
                  {p.originalPriceInr ? `₹${Number(p.originalPriceInr).toFixed(0)}` : '—'}
                </td>
                <td className="px-4 py-3"><BadgePill badge={p.badge} /></td>
                <td className="px-4 py-3 text-hint">{p.sortOrder}</td>
                <td className="px-4 py-3">
                  {p.isActive
                    ? <span className="text-xs bg-green-500/15 text-green-400 px-2 py-0.5 rounded-full">Active</span>
                    : <span className="text-xs bg-hint/15 text-hint px-2 py-0.5 rounded-full">Inactive</span>}
                </td>
                <td className="px-4 py-3">
                  <div className="flex gap-2">
                    <button onClick={() => editPkg(p)} className="text-xs bg-blue-500/10 text-blue-400 px-2 py-1 rounded-lg hover:bg-blue-500/20 flex items-center gap-1">
                      <Pencil size={11} />Edit
                    </button>
                    <button onClick={() => remove(p.id)} className="text-xs bg-red-500/10 text-red-400 px-2 py-1 rounded-lg hover:bg-red-500/20 flex items-center gap-1">
                      <Trash2 size={11} />Delete
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
