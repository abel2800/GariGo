import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gari_core/gari_core.dart';

import '../../shared/providers/providers.dart';

class TripChatScreen extends ConsumerStatefulWidget {
  const TripChatScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends ConsumerState<TripChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = ref.read(apiProvider).client.socket;
      ref.read(apiProvider).client.joinTrip(widget.tripId);
      socket?.off('trip_message');
      socket?.on('trip_message', _onSocketMessage);
    });
  }

  void _onSocketMessage(dynamic data) {
    final m = Map<String, dynamic>.from(data as Map);
    if (m['tripId']?.toString() != widget.tripId) return;
    if (!mounted) return;
    setState(() {
      if (_messages.any((e) => e['id']?.toString() == m['id']?.toString())) {
        return;
      }
      _messages.add(m);
    });
    _scrollToEnd();
  }

  Future<void> _load() async {
    try {
      final list =
          await ref.read(apiProvider).client.tripMessages(widget.tripId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _loading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg =
          await ref.read(apiProvider).client.sendTripMessage(widget.tripId, text);
      _ctrl.clear();
      if (!mounted) return;
      setState(() {
        if (!_messages.any((e) => e['id']?.toString() == msg['id']?.toString())) {
          _messages.add(msg);
        }
        _sending = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  void dispose() {
    ref.read(apiProvider).client.socket?.off('trip_message');
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final meRole = 'rider';

    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(
        backgroundColor: GariColors.cream,
        title: Text(isAm ? 'ከሹፌር ጋር መልእክት' : 'Message driver'),
      ),
      body: Column(
        children: [
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(_error!,
                    style: AppText.caption(context, color: GariColors.crimson)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final mine = m['senderRole']?.toString() == meRole;
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: mine ? GariColors.nightBlue : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: mine
                            ? null
                            : Border.all(color: GariColors.border, width: 1.5),
                      ),
                      child: Text(
                        '${m['body']}',
                        style: TextStyle(
                          color: mine ? Colors.white : GariColors.nightBlue,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: GariColors.border, width: 1.5),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: isAm ? 'መልእክት ይጻፉ…' : 'Type a message…',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: GariColors.amber,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _sending ? null : _send,
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.send_rounded,
                            color: Color(0xFF1A1408)),
                      ),
                    ),
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
