import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

class ListenerHelpSupportScreen extends StatefulWidget {
  const ListenerHelpSupportScreen({super.key});
  @override
  State<ListenerHelpSupportScreen> createState() => _ListenerHelpSupportScreenState();
}

class _ListenerHelpSupportScreenState extends State<ListenerHelpSupportScreen> {
  List<dynamic> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await api.get(ApiEndpoints.supportTickets);
      final data = resp.data['data'];
      final list = (data is List) ? data : (data is Map && data['data'] is List) ? data['data'] as List : <dynamic>[];
      if (mounted) setState(() { _tickets = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Create Ticket Dialog ──────────────────────────────────────────────────
  Future<void> _showRaiseTicketDialog() async {
    final l = AppLocalizations.current;
    final subjectCtrl     = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final formKey         = GlobalKey<FormState>();
    bool submitting       = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle bar
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(l.raiseTicket, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary)),
              const SizedBox(height: 20),

              // Subject field
              TextFormField(
                controller: subjectCtrl,
                decoration: InputDecoration(
                  labelText: l.subject,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '${l.subject} required' : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),

              // Description field
              TextFormField(
                controller: descriptionCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l.description,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
                validator: (v) => (v == null || v.trim().length < 10) ? 'Min 10 characters' : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModal(() => submitting = true);
                          try {
                            await api.post(ApiEndpoints.supportTickets, data: {
                              'subject': subjectCtrl.text.trim(),
                              'message': descriptionCtrl.text.trim(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load(); // refresh list
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ticket submitted successfully'), backgroundColor: AppColors.success),
                              );
                            }
                          } catch (e) {
                            setModal(() => submitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(l.submit, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    subjectCtrl.dispose();
    descriptionCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.current;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(l.helpSupport),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRaiseTicketDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(l.raiseTicket, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _tickets.isEmpty
                      ? _buildEmpty(l)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _tickets.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _TicketCard(
                            ticket: _tickets[i] as Map<String, dynamic>,
                            onTap: () => context.push('/listener/support/${_tickets[i]['id']}').then((_) => _load()),
                          ),
                        ),
                ),
    );
  }

  Widget _buildEmpty(AppLocalizations l) => ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.support_agent, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                l.noTickets,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
            ]),
          ),
        ],
      );

  Widget _buildError() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      );
}

// ─── Ticket Card ─────────────────────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;
  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status    = ticket['status'] as String? ?? 'OPEN';
    final subject   = ticket['subject'] as String? ?? 'Support Request';
    final createdAt = ticket['createdAt'] as String?;
    final replies   = (ticket['replies'] as List?)?.length ?? 0;
    final lastReply = (ticket['replies'] as List?)?.isNotEmpty == true
        ? (ticket['replies'] as List).last['message'] as String?
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            _StatusChip(status: status),
          ]),
          if (lastReply != null) ...[
            const SizedBox(height: 6),
            Text(lastReply, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.chat_bubble_outline, size: 13, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text('$replies replies', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
            const Spacer(),
            if (createdAt != null)
              Text(
                DateFormat('dd MMM yyyy').format(DateTime.parse(createdAt)),
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'OPEN':        AppColors.primary,
      'IN_PROGRESS': AppColors.busy,
      'RESOLVED':    AppColors.success,
      'CLOSED':      AppColors.textHint,
    };
    final color = colors[status] ?? AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
