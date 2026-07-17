import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/chat_service.dart';

/// In-trip chat screen.
///
/// Connects to /ws/ride/trip/<id>/chat/ for live messages and falls
/// back to the REST history endpoint for backfill on screen-open.
/// Both rider and driver use the same screen; the backend stamps
/// `sender_role` so the UI can lane the bubbles correctly.
class TripChatScreen extends StatefulWidget {
  final int tripId;
  final String myRole;
  const TripChatScreen({super.key, required this.tripId, required this.myRole});

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
  final ChatService _svc = ChatService();
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _sub;
  String? _token;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    if (_token == null) {
      setState(() => _loading = false);
      return;
    }
    final history = await _svc.fetchHistory(
      tripId: widget.tripId,
      token: _token!,
    );
    if (!mounted) return;
    setState(() {
      _messages.addAll(history);
      _loading = false;
    });
    _sub = _svc.events.listen(_onEvent);
    _svc.connect(tripId: widget.tripId, token: _token!);
    _svc.markRead();
    _scrollToBottom();
  }

  void _onEvent(Map<String, dynamic> event) {
    final t = event['type'];
    if (t == 'message') {
      setState(() {
        _messages.add(event);
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    _svc.send(body);
    _ctrl.clear();
    // Optimistic local echo so the message appears immediately;
    // server will broadcast the canonical version back to all peers.
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'sender_role': widget.myRole,
        'body': body,
        'is_system': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _svc.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF15140F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15140F),
        title: Text(
          'Trip chat',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFEEBD2B)),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isMine = m['sender_role'] == widget.myRole;
                      final isSystem =
                          m['is_system'] == true ||
                          m['sender_role'] == 'system';
                      return _Bubble(
                        body: (m['body'] ?? '').toString(),
                        isMine: isMine,
                        isSystem: isSystem,
                        createdAt: m['created_at']?.toString(),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: const Color(0xFF1E1B14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Message your driver',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF24211C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFFEEBD2B)),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.body,
    required this.isMine,
    required this.isSystem,
    this.createdAt,
  });
  final String body;
  final bool isMine;
  final bool isSystem;
  final String? createdAt;

  @override
  Widget build(BuildContext context) {
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            body,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isMine ? const Color(0xFFEEBD2B) : const Color(0xFF24211C);
    final fg = isMine ? Colors.black : Colors.white;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: GoogleFonts.inter(color: fg, fontSize: 14)),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(createdAt!),
                style: GoogleFonts.inter(
                  color: fg.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}
