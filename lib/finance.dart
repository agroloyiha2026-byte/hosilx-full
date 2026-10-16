import 'package:flutter/material.dart';
import 'main.dart';

const _F = {
  'uz': {
    'title': 'Moliya', 'income': 'Daromad', 'expense': 'Xarajat', 'profit': 'Foyda / zarar', 'amount': 'Summa', 
    'note': 'Izoh', 'planned': 'Rejalashtirilgan', 'add': 'Qo‘shish', 
    'none': 'Hali yozuv yo‘q. Daromad yoki xarajat qo‘shing.', 'cur': 'Valyutalar alohida hisoblanadi.', 'bad': 'Summani to‘g‘ri kiriting'
  },
  'ru': {
    'title': 'Финансы', 'income': 'Доход', 'expense': 'Расход', 'profit': 'Прибыль / убыток', 'amount': 'Сумма', 
    'note': 'Заметка', 'planned': 'Запланировано', 'add': 'Добавить', 
    'none': 'Записей пока нет. Добавьте доход или расход.', 'cur': 'Валюты считаются отдельно.', 'bad': 'Введите корректную сумму'
  },
  'en': {
    'title': 'Finance', 'income': 'Income', 'expense': 'Expense', 'profit': 'Profit / loss', 'amount': 'Amount', 
    'note': 'Note', 'planned': 'Planned', 'add': 'Add', 
    'none': 'No entries yet. Add income or an expense.', 'cur': 'Currencies are calculated separately.', 'bad': 'Enter a valid amount'
  },
};
String _f(String k) => _F[lang.value]![k] ?? k;
String financeTitle() => _f('title');

class FinancePage extends StatefulWidget { const FinancePage({super.key}); @override State<FinancePage> createState() => _FinState(); }
class _FinState extends State<FinancePage> {
  late Future<List> f = load();
  Future<List> load() => sb().from('finance_entries').select('id,kind,category,amount,currency,planned,entry_date,note')
      .eq('user_id', sb().auth.currentUser!.id).order('entry_date', ascending: false).limit(200);
  void reload() => setState(() => f = load());

  Future<void> addDialog() async {
    String kind = 'expense', cat = 'seeds', cur = 'UZS'; bool planned = false;
    final amount = TextEditingController(), note = TextEditingController(); String? err;
    await showDialog(
      context: context, 
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(_f('add')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                DropdownButton<String>(
                  value: kind, 
                  isExpanded: true, 
                  items: [
                    DropdownMenuItem(value: 'income', child: Text(_f('income'))), 
                    DropdownMenuItem(value: 'expense', child: Text(_f('expense')))
                  ], 
                  onChanged: (v) => set(() => kind = v!)
                ),
                DropdownButton<String>(
                  value: cat, 
                  isExpanded: true, 
                  items: const ['sales', 'seeds', 'fertilizer', 'labor', 'transport', 'storage', 'other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
                  onChanged: (v) => set(() => cat = v!)
                ),
                DropdownButton<String>(
                  value: cur, 
                  isExpanded: true, 
                  items: const ['UZS', 'USD'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
                  onChanged: (v) => set(() => cur = v!)
                ),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _f('amount'))),
                TextField(controller: note, decoration: InputDecoration(labelText: _f('note'))),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(_f('planned')), value: planned, onChanged: (v) => set(() => planned = v)),
                if (err != null) Text(err!, style: const TextStyle(color: Colors.red))
              ]
            )
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('✕')),
            FilledButton(
              onPressed: () async {
                final a = double.tryParse(amount.text.replaceAll(' ', ''));
                if (a == null || a <= 0) { set(() => err = _f('bad')); return; }
                try {
                  await sb().from('finance_entries').insert({
                    'user_id': sb().auth.currentUser!.id, 
                    'kind': kind, 
                    'category': cat, 
                    'amount': a, 
                    'currency': cur,
                    'planned': planned, 
                    'entry_date': DateTime.now().toIso8601String().substring(0, 10), 
                    'note': note.text.trim().isEmpty ? null : note.text.trim()
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) { set(() => err = t('error')); }
              }, 
              child: Text(_f('add'))
            )
          ]
        )
      )
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(_f('title'))),
    floatingActionButton: FloatingActionButton(onPressed: addDialog, child: const Icon(Icons.add)),
    body: FutureBuilder<List>(
      future: f, 
      builder: (_, s) {
        if (s.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(t('error')), TextButton(onPressed: reload, child: Text(t('retry')))]));
        if (!s.hasData) return Center(child: Text(t('loading')));
        final totals = <String, List<double>>{};
        for (final x in s.data!.where((e) => e['planned'] != true)) {
          final t0 = totals.putIfAbsent(x['currency'], () => [0, 0]);
          t0[x['kind'] == 'income' ? 0 : 1] += (x['amount'] as num).toDouble();
        }
        if (s.data!.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_f('none'), textAlign: TextAlign.center)));
        return ListView(
          padding: const EdgeInsets.all(16), 
          children: [
            for (final e in totals.entries) Card(
              child: Padding(
                padding: const EdgeInsets.all(12), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(e.key, style: Theme.of(c).textTheme.labelLarge), 
                    Text('${_f('income')}: ${e.value[0].toStringAsFixed(0)}'), 
                    Text('${_f('expense')}: ${e.value[1].toStringAsFixed(0)}'),
                    Text('${_f('profit')}: ${(e.value[0] - e.value[1]).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))
                  ]
                )
              )
            ),
            Text(_f('cur'), style: Theme.of(c).textTheme.bodySmall), 
            const SizedBox(height: 8),
            for (final x in s.data!) Card(
              child: ListTile(
                title: Text('${x['kind'] == 'income' ? '＋' : '－'}${x['amount']} ${x['currency']}'),
                subtitle: Text('${x['entry_date']} · ${x['category']}${x['planned'] == true ? ' · ${_f('planned')}' : ''}${x['note'] != null ? ' · ${x['note']}' : ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline), 
                  onPressed: () async { 
                    await sb().from('finance_entries').delete().eq('id', x['id']); 
                    reload(); 
                  }
                )
              )
            )
          ]
        );
      }
    )
  );
}
