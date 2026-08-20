import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

class ListenerSupportDetailScreen extends StatefulWidget {
  final String ticketId;
  const ListenerSupportDetailScreen({super.key, required this.ticketId});
  @override
  State<ListenerSupportDetailScreen> createState() => _ListenerSupportDetailScreenState();
}

class _ListenerSupportDetailScreenState extends State<ListenerSupportDetailScreen> {
  Map<String, dynamic>? _ticket;
  List<dynamic> _replies = [];
  bool _loading = true;
  bool _sending = false;
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final resp = await api.get(ApiEndpoints.supportTicket(widget.ticketId));
      final data = resp.data['data'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _ticket  = data;
          _replies = (data['replies'] as List<dynamic>?) ?? [];
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await api.post(ApiEndpoints.ticketReply(widget.ticketId), data: {'message': text});
      _replyCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l      = AppLocalizations.current;
    final status = _ticket?['status'] as String? ?? '';
    final isClosed = status == 'CLOSED' || status == 'RESOLVED';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(_ticket?['subject'] as String? ?? l.helpSupport, style: const TextStyle(fontSize: 15)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _StatusBadge(status: status),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              // Message list
              Expanded(
                child: _replies.isEmpty
                    ? const Center(child: Text('No messages yet.', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _replies.length,
                        itemBuilder: (_, i) => _ReplyBubble(reply: _replies[i] as Map<String, dynamic>),
                      ),
              ),

              // Reply input (disabled when closed/resolved)
              if (!isClosed)
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(16, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _replyCtrl,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: l.typeMessage,
                          hintStyle: const TextStyle(color: AppColors.textHint),
                          filled: true,
                          fillColor: const Color(0xFFF2F2F7),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _sending
                        ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : IconButton(
                            onPressed: _sendReply,
                            icon: const Icon(Icons.send_rounded),
                            color: AppColors.primary,
                            iconSize: 24,
                            style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1)),
                          ),
                  ]),
                )
              else
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'This ticket is $status. No further replies.',
                      style: const TextStyle(color: AppColors.textHint, fontSize: 13),
                    ),
                  ),
                ),
            ]),
    );
  }
}

// ── Reply Bubble ──────────────────────────────────────────────────────────────
class _ReplyBubble extends StatelessWidget {
  final Map<String, dynamic> reply;
  const _ReplyBubble({required this.reply});

  @override
  Widget build(BuildContext context) {
    final isAdmin   = reply['isAdmin'] as bool? ?? false;
    final message   = reply['message'] as String? ?? '';
    final createdAt = reply['createdAt'] as String?;

    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isAdmin ? Colors.white : AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isAdmin ? 4 : 16),
            bottomRight: Radius.circular(isAdmin ? 16 : 4),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isAdmin) Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 20, height: 20, decoration: BoxDecoration(color: AppColors.accentStart.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.support_agent, size: 11, color: AppColors.accentStart)),
              const SizedBox(width: 6),
              const Text('Support Team', style: TextStyle(color: AppColors.accentStart, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
          Text(message, style: TextStyle(color: isAdmin ? AppColors.textPrimary : Colors.white, fontSize: 14, height: 1.4)),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM, hh:mm a').format(DateTime.parse(createdAt)),
              style: TextStyle(color: isAdmin ? AppColors.textHint : Colors.white60, fontSize: 10),
            ),
          ],
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final colors = {'OPEN': AppColors.primary, 'IN_PROGRESS': AppColors.busy, 'RESOLVED': AppColors.success, 'CLOSED': AppColors.textHint};
    final color = colors[status] ?? AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
