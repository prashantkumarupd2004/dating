'use client';
import { useEffect, useState, useCallback } from 'react';
import { api } from '../../../lib/api';
import { Search, CheckCircle, XCircle, PauseCircle, PlayCircle, ChevronDown, ChevronUp, Mic, Phone, Video } from 'lucide-react';
import toast from 'react-hot-toast';

const STATUS_TABS = ['ALL', 'PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED'];
const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://15.252.165.123:5000';

export default function ListenersPage() {
  const [listeners, setListeners] = useState<any[]>([]);
  const [tab, setTab] = useState('PENDING');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [meta, setMeta] = useState<any>(null);
  const [expanded, setExpanded] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page) });
      if (tab !== 'ALL') params.set('status', tab);
      if (search) params.set('search', search);
      const response = await api.get(`/admin/listeners?${params}`);
      // Backend returns {success: true, data: {listeners: [...], meta: {...}}}
      const data = response.data || response;
      setListeners(data.listeners || []);
      setMeta(data.meta || null);
    } catch (err) {
      console.error('Failed to load listeners:', err);
      toast.error('Failed to load listeners');
    }
    setLoading(false);
  }, [page, tab, search]);

  useEffect(() => { load(); }, [load]);

  const action = async (id: string, endpoint: string, label: string, body?: any) => {
    try {
      await api.post(`/admin/listeners/${id}/${endpoint}`, body ?? {});
      toast.success(`${label} successful`); load();
    } catch { toast.error(`${label} failed`); }
  };

  const statusBadge = (s: string) => {
    const map: any = {
      APPROVED: 'bg-green-500/15 text-green-400',
      PENDING: 'bg-yellow-500/15 text-yellow-400',
      REJECTED: 'bg-red-500/15 text-red-400',
      SUSPENDED: 'bg-gray-500/15 text-gray-400',
    };
    return <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${map[s] || ''}`}>{s}</span>;
  };

  const calcAge = (dob: string) => {
    if (!dob) return '—';
    const diff = Date.now() - new Date(dob).getTime();
    return Math.floor(diff / (365.25 * 24 * 60 * 60 * 1000)) + ' yrs';
  };

  const hasVoice = (l: any) =>
    l.documents?.some((d: any) => d.type === 'VOICE_SAMPLE');

  const voiceUrl = (l: any) => {
    const doc = l.documents?.find((d: any) => d.type === 'VOICE_SAMPLE');
    if (!doc?.fileUrl) return null;
    // Avoid double slash — fileUrl may or may not have leading slash
    const cleanPath = doc.fileUrl.startsWith('/') ? doc.fileUrl : `/${doc.fileUrl}`;
    return `${API_BASE}${cleanPath}`;
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Listeners</h1>

      {/* Status tabs */}
      <div className="flex gap-2 mb-5 overflow-x-auto">
        {STATUS_TABS.map(t => (
          <button key={t} onClick={() => { setTab(t); setPage(1); }}
            className={`px-4 py-2 rounded-xl text-sm font-medium whitespace-nowrap transition ${tab === t ? 'bg-primary text-white' : 'bg-card text-hint hover:text-white'}`}>
            {t}
          </button>
        ))}
      </div>

      {/* Search */}
      <div className="flex gap-3 mb-4">
        <div className="relative flex-1 max-w-sm">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-hint" />
          <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search listeners…"
            className="w-full bg-card border border-border rounded-xl pl-9 pr-4 py-2.5 text-sm focus:outline-none focus:border-primary" />
        </div>
      </div>

      {/* Table */}
      <div className="bg-card border border-border rounded-2xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="border-b border-border">
            <tr className="text-hint text-xs uppercase">
              <th className="text-left px-4 py-3 w-8"></th>
              <th className="text-left px-4 py-3">Listener</th>
              <th className="text-left px-4 py-3">Age</th>
              <th className="text-left px-4 py-3">State / City</th>
              <th className="text-left px-4 py-3">Relationship</th>
              <th className="text-left px-4 py-3">Voice</th>
              <th className="text-left px-4 py-3">Calls</th>
              <th className="text-left px-4 py-3">Status</th>
              <th className="text-left px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading
              ? <tr><td colSpan={9} className="text-center py-12 text-hint">Loading…</td></tr>
              : listeners.map(l => (
                <>
                  {/* Main row */}
                  <tr key={l.id} className="border-b border-border/50 hover:bg-surface/40 transition">
                    {/* Expand toggle */}
                    <td className="px-3 py-3">
                      <button onClick={() => setExpanded(expanded === l.id ? null : l.id)}
                        className="text-hint hover:text-white transition">
                        {expanded === l.id ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
                      </button>
                    </td>

                    {/* Name + contact */}
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-full bg-primary/20 flex items-center justify-center font-bold text-primary text-sm shrink-0">
                          {l.profile?.displayName?.[0]?.toUpperCase() ?? '?'}
                        </div>
                        <div>
                          <div className="font-semibold">{l.profile?.displayName ?? '—'}</div>
                          <div className="text-xs text-hint">{l.user?.email || l.user?.phone || '—'}</div>
                        </div>
                      </div>
                    </td>

                    {/* Age */}
                    <td className="px-4 py-3 text-sm">
                      {l.profile?.dateOfBirth ? calcAge(l.profile.dateOfBirth) : '—'}
                    </td>

                    {/* State / City */}
                    <td className="px-4 py-3">
                      <div className="text-sm font-medium">{l.profile?.state ?? '—'}</div>
                      <div className="text-xs text-hint">{l.profile?.city ?? '—'}</div>
                    </td>

                    {/* Relationship Status */}
                    <td className="px-4 py-3 text-xs">
                      {l.profile?.relationshipStatus
                        ? <span className="bg-pink-500/10 text-pink-400 px-2 py-0.5 rounded-full">{l.profile.relationshipStatus}</span>
                        : <span className="text-hint">—</span>}
                    </td>

                    {/* Voice Verification */}
                    <td className="px-4 py-3">
                      {hasVoice(l)
                        ? <span className="flex items-center gap-1 text-xs bg-green-500/15 text-green-400 px-2 py-0.5 rounded-full w-fit">
                            <Mic size={10} /> Uploaded
                          </span>
                        : <span className="text-xs text-hint flex items-center gap-1"><Mic size={10} /> None</span>}
                    </td>

                    {/* Call types */}
                    <td className="px-4 py-3">
                      <div className="flex gap-1 flex-wrap">
                        {l.isAudioEnabled && <span className="text-xs bg-blue-500/10 text-blue-400 px-2 py-0.5 rounded-full flex items-center gap-1"><Phone size={9} />Audio</span>}
                        {l.isVideoEnabled && <span className="text-xs bg-purple-500/10 text-purple-400 px-2 py-0.5 rounded-full flex items-center gap-1"><Video size={9} />Video</span>}
                      </div>
                    </td>

                    {/* Status */}
                    <td className="px-4 py-3">{statusBadge(l.status)}</td>

                    {/* Actions */}
                    <td className="px-4 py-3">
                      <div className="flex gap-2 flex-wrap">
                        {l.status === 'PENDING' && <>
                          <button onClick={() => action(l.id, 'approve', 'Approve')}
                            className="text-xs bg-green-500/10 text-green-400 px-3 py-1 rounded-lg hover:bg-green-500/20 transition flex items-center gap-1">
                            <CheckCircle size={12} />Approve
                          </button>
                          <button onClick={() => action(l.id, 'reject', 'Reject', { reason: 'Does not meet requirements' })}
                            className="text-xs bg-red-500/10 text-red-400 px-3 py-1 rounded-lg hover:bg-red-500/20 transition flex items-center gap-1">
                            <XCircle size={12} />Reject
                          </button>
                        </>}
                        {l.status === 'APPROVED' && (
                          <button onClick={() => action(l.id, 'suspend', 'Suspend', { reason: 'Admin action' })}
                            className="text-xs bg-yellow-500/10 text-yellow-400 px-3 py-1 rounded-lg hover:bg-yellow-500/20 transition flex items-center gap-1">
                            <PauseCircle size={12} />Suspend
                          </button>
                        )}
                        {l.status === 'SUSPENDED' && (
                          <button onClick={() => action(l.id, 'reactivate', 'Reactivate')}
                            className="text-xs bg-green-500/10 text-green-400 px-3 py-1 rounded-lg hover:bg-green-500/20 transition flex items-center gap-1">
                            <PlayCircle size={12} />Reactivate
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>

                  {/* Expanded detail row */}
                  {expanded === l.id && (
                    <tr key={`${l.id}-detail`} className="bg-surface/30 border-b border-border/50">
                      <td colSpan={9} className="px-6 py-4">
                        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">

                          {/* Full Name */}
                          <div>
                            <div className="text-xs text-hint mb-1">Full Display Name</div>
                            <div className="font-semibold">{l.profile?.displayName ?? '—'}</div>
                          </div>

                          {/* DOB + Age */}
                          <div>
                            <div className="text-xs text-hint mb-1">Date of Birth / Age</div>
                            <div className="font-semibold">
                              {l.profile?.dateOfBirth
                                ? `${new Date(l.profile.dateOfBirth).toLocaleDateString('en-IN')} (${calcAge(l.profile.dateOfBirth)})`
                                : '—'}
                            </div>
                          </div>

                          {/* State */}
                          <div>
                            <div className="text-xs text-hint mb-1">State</div>
                            <div className="font-semibold">{l.profile?.state ?? '—'}</div>
                          </div>

                          {/* City */}
                          <div>
                            <div className="text-xs text-hint mb-1">City</div>
                            <div className="font-semibold">{l.profile?.city ?? '—'}</div>
                          </div>

                          {/* Relationship Status */}
                          <div>
                            <div className="text-xs text-hint mb-1">Relationship Status</div>
                            <div className="font-semibold">{l.profile?.relationshipStatus ?? '—'}</div>
                          </div>

                          {/* Languages */}
                          <div>
                            <div className="text-xs text-hint mb-1">Languages</div>
                            <div className="flex flex-wrap gap-1 mt-1">
                              {l.profile?.languages?.length
                                ? l.profile.languages.map((lang: string) => (
                                    <span key={lang} className="text-xs bg-primary/10 text-primary px-2 py-0.5 rounded-full">{lang}</span>
                                  ))
                                : <span className="text-hint">—</span>}
                            </div>
                          </div>

                          {/* Bio */}
                          <div className="col-span-2">
                            <div className="text-xs text-hint mb-1">Bio</div>
                            <div className="text-sm">{l.profile?.bio || '—'}</div>
                          </div>

                          {/* Voice Verification */}
                          <div className="col-span-2 md:col-span-1">
                            <div className="text-xs text-hint mb-1">Voice Verification</div>
                             {(() => {
                               const url = voiceUrl(l);
                               if (!url) return (
                                 <span className="text-xs text-red-400 flex items-center gap-1">
                                   <Mic size={10} /> Not uploaded ✗
                                 </span>
                               );
                               return (
                                 <div>
                                   <span className="text-xs bg-green-500/15 text-green-400 px-2 py-0.5 rounded-full flex items-center gap-1 w-fit mb-2">
                                     <Mic size={10} /> Sample Uploaded ✓
                                   </span>
                                   <audio
                                     controls
                                     preload="metadata"
                                     className="h-10 w-full max-w-xs"
                                     crossOrigin="anonymous"
                                     onError={(e) => {
                                       const el = e.currentTarget;
                                       el.outerHTML = `<a href="${url}" target="_blank" rel="noreferrer" class="text-xs text-blue-400 underline">▶ Open Audio File</a>`;
                                     }}
                                   >
                                     <source src={url} type="audio/mpeg" />
                                     <source src={url} type="audio/mp4" />
                                     <source src={url} type="audio/ogg" />
                                     <source src={url} type="audio/wav" />
                                   </audio>
                                   <a href={url} target="_blank" rel="noreferrer"
                                     className="text-xs text-blue-400 underline mt-1 block">
                                     ↗ Open in new tab
                                   </a>
                                 </div>
                               );
                             })()}
                          </div>

                          {/* Admin Notes */}
                          {l.adminNotes && (
                            <div className="col-span-2">
                              <div className="text-xs text-hint mb-1">Admin Notes</div>
                              <div className="text-sm text-yellow-400">{l.adminNotes}</div>
                            </div>
                          )}

                          {/* Rejection Reason */}
                          {l.rejectionReason && (
                            <div className="col-span-2">
                              <div className="text-xs text-hint mb-1">Rejection Reason</div>
                              <div className="text-sm text-red-400">{l.rejectionReason}</div>
                            </div>
                          )}

                          {/* Applied At */}
                          <div>
                            <div className="text-xs text-hint mb-1">Applied At</div>
                            <div className="text-sm">{new Date(l.createdAt).toLocaleString('en-IN')}</div>
                          </div>
                        </div>
                      </td>
                    </tr>
                  )}
                </>
              ))}
          </tbody>
        </table>

        {/* Pagination */}
        {meta && (
          <div className="px-4 py-3 flex justify-between items-center border-t border-border text-sm text-hint">
            <span>Total: {meta.total}</span>
            <div className="flex gap-2">
              <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={!meta.hasPrev}
                className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40">Prev</button>
              <span className="px-3 py-1">{meta.page} / {meta.totalPages}</span>
              <button onClick={() => setPage(p => p + 1)} disabled={!meta.hasNext}
                className="px-3 py-1 rounded-lg bg-surface disabled:opacity-40">Next</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
