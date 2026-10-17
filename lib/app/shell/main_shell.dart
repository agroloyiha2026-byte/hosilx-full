import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../localization/l10n.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  final String location;
  const MainShell({super.key, required this.child, required this.location});

  static const _paths = ['/', '/market', '/favorites', '/profile'];

  @override
  Widget build(BuildContext context) {
    final idx = _paths.indexWhere((p) => p == '/' ? location == '/' : location.startsWith(p));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx < 0 ? 0 : idx,
        onDestinationSelected: (i) => context.go(_paths[i]),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: context.tr('nav_home')),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront), label: context.tr('nav_market')),
          NavigationDestination(icon: const Icon(Icons.favorite_border), selectedIcon: const Icon(Icons.favorite), label: context.tr('nav_favorites')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: context.tr('nav_profile')),
        ],
      ),
    );
  }
}
