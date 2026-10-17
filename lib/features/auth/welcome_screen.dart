import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _S();
}

class _S extends State<WelcomeScreen> {
  final _page = PageController();
  int _i = 0;
  static const _slides = [('🛒', 'ob1'), ('🏭', 'ob2'), ('🤖', 'ob3')];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 24),
            Text('🌾 ${context.tr('welcome_title')}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(context.tr('welcome_sub'), textAlign: TextAlign.center),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (v) => setState(() => _i = v),
                children: [
                  for (final s in _slides)
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(s.$1, style: const TextStyle(fontSize: 72)),
                      const SizedBox(height: 16),
                      Text(context.tr(s.$2), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    ]),
                ],
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < _slides.length; k++)
                AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.all(4), width: k == _i ? 22 : 8, height: 8,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: k == _i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.25))),
            ]),
            const SizedBox(height: 20),
            AppButton(
              label: context.tr(last ? 'get_started' : 'next'),
              onPressed: () => last ? context.go('/register') : _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.go('/login'), child: Text(context.tr('login'))),
          ]),
        ),
      ),
    );
  }
}
