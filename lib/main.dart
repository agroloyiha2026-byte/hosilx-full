// Ishga tushirish uchun argumentlar:
// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=WEB_URL=https://your-site.vercel.app
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'forms.dart';
import 'finance.dart';

const webUrl = String.fromEnvironment('WEB_URL');
final sb = () => Supabase.instance.client;
final lang = ValueNotifier<String>('uz');
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

const S = {
  'uz': {
    'home': 'Bosh sahifa', 'market': 'Bozor', 'wh': 'Omborlar', 'ai': 'AI', 'profile': 'Profil', 
    'email': 'Email', 'pass': 'Parol', 'signin': 'Kirish', 'logout': 'Chiqish', 
    'loading': 'Yuklanmoqda...', 'error': 'Yuklab bo‘lmadi. Internetni tekshiring.', 'retry': 'Qayta urinish',
    'empty': 'Hozircha ma’lumot yo‘q.', 'send': 'Yuborish', 'ask': 'Savolingizni yozing...', 
    'tasks': 'Bugungi vazifalar', 'notasks': 'Bugun vazifa yo‘q.', 'dark': 'Tungi rejim', 
    'lang': 'Til', 'bad': 'Email yoki parol noto‘g‘ri.', 'free': 'bo‘sh'
  },
  'ru': {
    'home': 'Главная', 'market': 'Рынок', 'wh': 'Склады', 'ai': 'AI', 'profile': 'Профиль', 
    'email': 'Email', 'pass': 'Пароль', 'signin': 'Войти', 'logout': 'Выйти', 
    'loading': 'Загрузка...', 'error': 'Не удалось загрузить. Проверьте интернет.', 'retry': 'Повторить',
    'empty': 'Пока нет данных.', 'send': 'Отправить', 'ask': 'Задайте вопрос...', 
    'tasks': 'Задачи на сегодня', 'notasks': 'На сегодня задач нет.', 'dark': 'Тёмная тема', 
    'lang': 'Язык', 'bad': 'Неверный email или пароль.', 'free': 'свободно'
  },
  'en': {
    'home': 'Home', 'market': 'Market', 'wh': 'Warehouses', 'ai': 'AI', 'profile': 'Profile', 
    'email': 'Email', 'pass': 'Password', 'signin': 'Sign in', 'logout': 'Sign out', 
    'loading': 'Loading...', 'error': 'Could not load. Check your connection.', 'retry': 'Retry',
    'empty': 'No data yet.', 'send': 'Send', 'ask': 'Ask a question...', 
    'tasks': "Today's tasks", 'notasks': 'No tasks today.', 'dark': 'Dark mode', 
    'lang': 'Language', 'bad': 'Wrong email or password.', 'free': 'free'
  },
};
String t(String k) => S[lang.value]![k] ?? k;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('https://qmrfyvxvmbkokldffpnq.supabase.co'),
    anonKey: const String.fromEnvironment('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtcmZ5dnh2bWJrb2tsZGZmcG5xIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjEyOTkwNCwiZXhwIjoyMTA3NzA1OTA0fQ.YbiV0HhmZEYuxB8Y41lhTsvD93OptUBo10b1VpsVbYc'),
  );
  final sp = await SharedPreferences.getInstance();
  lang.value = sp.getString('lang') ?? 'uz';
  themeMode.value = sp.getBool('dark') == true ? ThemeMode.dark : ThemeMode.light;
  runApp(const HosilApp());
}

ThemeData _theme(bool dark) {
  final scheme = dark
      ? const ColorScheme.dark(primary: Color(0xFF5FA85A), onPrimary: Color(0xFF0E1A10), surface: Color(0xFF1B261E))
      : const ColorScheme.light(primary: Color(0xFF3F7D3A), secondary: Color(0xFF8B6848), surface: Colors.white);
  return ThemeData(
    colorScheme: scheme, 
    useMaterial3: true,
    scaffoldBackgroundColor: dark ? const Color(0xFF111912) : const Color(0xFFF7F5ED),
    cardTheme: CardTheme(color: scheme.surface, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))
  );
}

class HosilApp extends StatelessWidget {
  const HosilApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
      valueListenable: lang,
      builder: (_, __, ___) => ValueListenableBuilder(
          valueListenable: themeMode,
          builder: (_, mode, __) => MaterialApp(
              title: 'Hosil X', 
              debugShowCheckedModeBanner: false, 
              themeMode: mode,
              theme: _theme(false), 
              darkTheme: _theme(true),
              home: StreamBuilder<AuthState>(
                  stream: sb().auth.onAuthStateChange,
                  builder: (_, __) => sb().auth.currentSession == null ? const LoginPage() : const Shell()))));
}

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginState(); }
class _LoginState extends State<LoginPage> {
  final e = TextEditingController(), p = TextEditingController();
  String? err; bool busy = false;

  Future<void> google() async {
    try {
      await sb().auth.signInWithOAuth(OAuthProvider.google, redirectTo: 'io.supabase.hosilx://login-callback/');
    } catch (_) { if (mounted) setState(() => err = t('error')); }
  }

  Future<void> go() async {
    setState(() { busy = true; err = null; });
    try { 
      await sb().auth.signInWithPassword(email: e.text.trim(), password: p.text); 
    } on AuthException { 
      err = t('bad'); 
    } catch (_) { 
      err = t('error'); 
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24), 
          child: Column(children: [
            const Text('🌾 Hosil X', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), 
            const SizedBox(height: 24),
            TextField(controller: e, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: t('email'))), 
            const SizedBox(height: 12),
            TextField(controller: p, obscureText: true, decoration: InputDecoration(labelText: t('pass'))), 
            const SizedBox(height: 12),
            if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12), 
            FilledButton(onPressed: busy ? null : go, child: Text(t('signin'))), 
            const SizedBox(height: 8), 
            OutlinedButton(onPressed: google, child: const Text('Google'))
          ])
        )
      )
    )
  );
}

class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _ShellState(); }
class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext c) {
    final pages = [const HomeTab(), const ListTab(table: 'products'), const ListTab(table: 'warehouses'), const AiTab(), const ProfileTab()];
    return Scaffold(
      body: SafeArea(child: pages[i]), 
      bottomNavigationBar: NavigationBar(
        selectedIndex: i, 
        onDestinationSelected: (v) => setState(() => i = v), 
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: t('home')),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), label: t('market')),
          NavigationDestination(icon: const Icon(Icons.warehouse_outlined), label: t('wh')),
          NavigationDestination(icon: const Icon(Icons.smart_toy_outlined), label: t('ai')),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: t('profile'))
        ]
      )
    );
  }
}

class HomeTab extends StatefulWidget { const HomeTab({super.key}); @override State<HomeTab> createState() => _HomeState(); }
class _HomeState extends State<HomeTab> {
  late Future<List> f = load();
  Future<List> load() {
    final end = DateTime.now().copyWith(hour: 23, minute: 59, second: 59).toUtc().toIso8601String();
    return sb().from('tasks').select('id,title,due_at').eq('user_id', sb().auth.currentUser!.id).eq('done', false).lte('due_at', end).order('due_at').limit(20);
  }
  void reload() => setState(() => f = load());

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: FloatingActionButton(
      onPressed: () async { await showAddTask(c); if (mounted) reload(); }, 
      child: const Icon(Icons.add)
    ),
    body: FutureBuilder<List>(
      future: f, 
      builder: (_, s) {
        if (s.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(t('error')), TextButton(onPressed: reload, child: Text(t('retry')))]));
        if (!s.hasData) return Center(child: Text(t('loading')));
        return ListView(
          padding: const EdgeInsets.all(16), 
          children: [
            Text(t('tasks'), style: Theme.of(c).textTheme.titleLarge), 
            const SizedBox(height: 8),
            if (s.data!.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(t('notasks')))),
            for (final x in s.data!) Card(
              child: ListTile(
                title: Text(x['title']), 
                subtitle: Text(DateTime.parse(x['due_at']).toLocal().toString().substring(0, 16)),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline), 
                  onPressed: () async { 
                    await sb().from('tasks').update({'done': true}).eq('id', x['id']); 
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

class ListTab extends StatefulWidget { final String table; const ListTab({super.key, required this.table}); @override State<ListTab> createState() => _ListState(); }
class _ListState extends State<ListTab> {
  late Future<List> f = load();
  Future<List> load() => widget.table == 'products'
      ? sb().from('products').select('id,title,price,currency,unit,quantity,region,image_url').eq('status', 'active').order('created_at', ascending: false).limit(50)
      : sb().from('warehouses').select('id,name,region,free_tons,capacity_tons,image_url').eq('status', 'active').order('created_at', ascending: false).limit(50);

  @override
  Widget build(BuildContext c) => FutureBuilder<List>(
    future: f, 
    builder: (_, s) {
      if (s.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(t('error')), TextButton(onPressed: () => setState(() => f = load()), child: Text(t('retry')))]));
      if (!s.hasData) return Center(child: Text(t('loading')));
      if (s.data!.isEmpty) return Center(child: Text(t('empty')));
      return ListView.builder(
        padding: const EdgeInsets.all(16), 
        itemCount: s.data!.length, 
        itemBuilder: (_, k) {
          final x = s.data![k]; final isP = widget.table == 'products';
          return Card(
            clipBehavior: Clip.antiAlias, 
            child: InkWell(
              onTap: isP ? () => showInquiry(c, x['id']) : () => showStorageRequest(c, x['id']), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3, 
                    child: x['image_url'] != null 
                        ? Image.network(x['image_url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🌿', style: TextStyle(fontSize: 40)))) 
                        : const Center(child: Text('🌿', style: TextStyle(fontSize: 40)))
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(isP ? x['title'] : x['name'], style: Theme.of(c).textTheme.titleMedium),
                        if (isP) Text('${x['price']} ${x['currency']}/${x['unit']}', style: TextStyle(color: Theme.of(c).colorScheme.primary, fontWeight: FontWeight.bold)),
                        Text(isP ? '${x['quantity']} ${x['unit']} · 📍 ${x['region']}' : '📍 ${x['region']} · ${x['free_tons']}/${x['capacity_tons']} t ${t('free')}')
                      ]
                    )
                  )
                ]
              )
            )
          );
        }
      );
    }
  );
}

class AiTab extends StatefulWidget { const AiTab({super.key}); @override State<AiTab> createState() => _AiState(); }
class _AiState extends State<AiTab> {
  final q = TextEditingController(); final msgs = <Map<String, String>>[]; bool busy = false;

  Future<void> send() async {
    final text = q.text.trim(); if (text.isEmpty || busy) return;
    setState(() { msgs.add({'role': 'user', 'content': text}); q.clear(); busy = true; });
    try {
      final r = await http.post(
        Uri.parse('$webUrl/api/ai'), 
        headers: {'content-type': 'application/json', 'authorization': 'Bearer ${sb().auth.currentSession!.accessToken}'}, 
        body: jsonEncode({'messages': msgs})
      );
      final out = r.statusCode == 200 ? jsonDecode(utf8.decode(r.bodyBytes))['text'] as String : t('error');
      msgs.add({'role': 'assistant', 'content': out});
    } catch (_) { msgs.add({'role': 'assistant', 'content': t('error')}); }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Column(children: [
    Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16), 
        children: [
          for (final m in msgs) Align(
            alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft, 
            child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(m['content']!)))
          )
        ]
      )
    ),
    if (busy) Text(t('loading')),
    Padding(
      padding: const EdgeInsets.all(12), 
      child: Row(children: [
        Expanded(child: TextField(controller: q, decoration: InputDecoration(hintText: t('ask')), onSubmitted: (_) => send())), 
        const SizedBox(width: 8), 
        FilledButton(onPressed: send, child: Text(t('send')))
      ])
    )
  ]);
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(16), 
    children: [
      Text(sb().auth.currentUser?.email ?? '', style: Theme.of(c).textTheme.titleMedium), 
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: lang.value, 
        decoration: InputDecoration(labelText: t('lang')),
        items: const [
          DropdownMenuItem(value: 'uz', child: Text('O‘zbekcha')), 
          DropdownMenuItem(value: 'ru', child: Text('Русский')), 
          DropdownMenuItem(value: 'en', child: Text('English'))
        ],
        onChanged: (v) async { 
          lang.value = v!; 
          (await SharedPreferences.getInstance()).setString('lang', v);
          await sb().from('profiles').update({'language': v}).eq('id', sb().auth.currentUser!.id); 
        }
      ),
      SwitchListTile(
        title: Text(t('dark')), 
        value: themeMode.value == ThemeMode.dark, 
        onChanged: (v) async {
          themeMode.value = v ? ThemeMode.dark : ThemeMode.light; 
          (await SharedPreferences.getInstance()).setBool('dark', v); 
        }
      ),
      OutlinedButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const FinancePage())), child: Text(financeTitle())), 
      const SizedBox(height: 8), 
      FilledButton(onPressed: () => showAddProduct(c), child: Text(lang.value == 'uz' ? 'Mahsulot qo‘shish' : lang.value == 'ru' ? 'Добавить продукт' : 'Add product')), 
      const SizedBox(height: 8), 
      OutlinedButton(onPressed: () => sb().auth.signOut(), child: Text(t('logout')))
    ]
  );
}
