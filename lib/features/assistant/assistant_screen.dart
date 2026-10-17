import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app/localization/l10n.dart';
import '../../core/config/env.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/widgets.dart';

/// AI kaliti ilovada saqlanmaydi: so'rov sayt serveridagi /api/ai ga ketadi (foydalanuvchi tokeni bilan).
/// WEB_URL sozlanmagan bo'lsa, o'ylab topilgan javob o'rniga sozlama holati ko'rsatiladi.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _S();
}

class _S extends State<AssistantScreen> {
  final _q = TextEditingController();
  final _msgs = <Map<String, String>>[];
  bool _busy = false;

  bool get _configured => Env.webUrl.startsWith('https://') && SupabaseService.ready;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _q.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() { _msgs.add({'role': 'user', 'content': text}); _q.clear(); _busy = true; });
    String answer;
    try {
      final token = SupabaseService.client.auth.currentSession?.accessToken;
      final res = await http.post(Uri.parse('${Env.webUrl}/api/ai'),
          headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
          body: jsonEncode({'messages': _msgs.length > 12 ? _msgs.sublist(_msgs.length - 12) : _msgs}));
      if (res.statusCode == 200) {
        answer = (jsonDecode(utf8.decode(res.bodyBytes))['text'] as String?) ?? '';
      } else {
        answer = context.tr(res.statusCode == 429 ? 'ai_limit' : 'error_generic');
      }
    } catch (_) {
      answer = context.tr('error_network');
    }
    if (mounted) setState(() { _msgs.add({'role': 'assistant', 'content': answer}); _busy = false; });
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    if (!_configured) {
      return Scaffold(appBar: AppBar(title: Text(context.tr('assistant'))),
          body: EmptyView(message: context.tr('assistant_unconfigured'), icon: Icons.settings_suggest_outlined));
    }
    return Scaffold(
      appBar: AppBar(title: Text('🤖 ${context.tr('assistant')}')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(context.tr('assistant_note'), style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final m in _msgs)
              Align(
                alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                  decoration: BoxDecoration(color: m['role'] == 'user' ? s.primaryContainer : s.surface, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: s.onSurface.withOpacity(0.08))),
                  child: SelectableText(m['content']!),
                ),
              ),
            if (_busy) const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: TextField(controller: _q, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: context.tr('ask_hint'), filled: true, fillColor: s.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
