'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { LayoutDashboard, Users, Headphones, Phone, Wallet, Package, CreditCard, DollarSign, Flag, Bell, Ticket, BarChart2, Settings, ScrollText, LogOut } from 'lucide-react';

const nav = [
  { label: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { label: 'Users', href: '/dashboard/users', icon: Users },
  { label: 'Listeners', href: '/dashboard/listeners', icon: Headphones },
  { label: 'Calls', href: '/dashboard/calls', icon: Phone },
  { label: 'Wallet', href: '/dashboard/wallet', icon: Wallet },
  { label: 'Coin Packages', href: '/dashboard/coin-packages', icon: Package },
  { label: 'Payments', href: '/dashboard/payments', icon: CreditCard },
  { label: 'Payouts', href: '/dashboard/payouts', icon: DollarSign },
  { label: 'Reports', href: '/dashboard/reports', icon: Flag },
  { label: 'Notifications', href: '/dashboard/notifications', icon: Bell },
  { label: 'Support', href: '/dashboard/support', icon: Ticket },
  { label: 'Analytics', href: '/dashboard/analytics', icon: BarChart2 },
  { label: 'Settings', href: '/dashboard/settings', icon: Settings },
  { label: 'Audit Logs', href: '/dashboard/audit-logs', icon: ScrollText },
];

export default function Sidebar() {
  const path = usePathname();
  const router = useRouter();

  const logout = () => {
    localStorage.removeItem('admin_token');
    router.push('/login');
  };

  return (
    <aside className="w-60 flex-shrink-0 bg-surface border-r border-border flex flex-col h-screen sticky top-0">
      <div className="px-6 py-5 border-b border-border flex items-center gap-3">
        <div className="w-9 h-9 rounded-xl bg-primary flex items-center justify-center font-bold text-white">C</div>
        <div>
          <div className="font-bold text-sm">Milan</div>
          <div className="text-xs text-hint">Jahan Dil Mile.</div>
        </div>
      </div>
      <nav className="flex-1 overflow-y-auto py-4 px-3 space-y-1">
        {nav.map(({ label, href, icon: Icon }) => {
          const active = path === href || (href !== '/dashboard' && path.startsWith(href));
          return (
            <Link
              key={href} href={href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition ${active ? 'bg-primary/15 text-primary' : 'text-muted hover:bg-card hover:text-white'}`}
            >
              <Icon size={17} />
              {label}
            </Link>
          );
        })}
      </nav>
      <div className="p-4 border-t border-border">
        <button onClick={logout} className="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-error hover:bg-error/10 w-full transition">
          <LogOut size={17} />
          Logout
        </button>
      </div>
    </aside>
  );
}
