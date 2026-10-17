import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/widgets.dart';
import '../features/auth/login_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/market/market_screen.dart';
import '../features/market/product_detail_screen.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/inquiries/inquiries_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/warehouses/warehouse_detail_screen.dart';
import '../features/warehouses/warehouses_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admin_moderation_screen.dart';
import '../features/admin/admin_users_screen.dart';
import '../features/products/my_products_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/admin/admin_categories_screen.dart';
import '../features/admin/admin_media_screen.dart';
import '../features/admin/admin_reports_screen.dart';
import '../features/admin/admin_settings_screen.dart';
import 'shell/main_shell.dart';
import '../features/auth/profile_setup_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/reset_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/auth/welcome_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';

const _publicRoutes = ['/welcome', '/login', '/register', '/reset'];

/// Yo'naltirish qoidalari: sessiya yo'q -> kirish sahifalari; profil to'ldirilmagan -> /setup;
/// aks holda -> asosiy ekran. Bu faqat qulaylik; haqiqiy xavfsizlik Supabase RLS da.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (s.loading) return loc == '/splash' ? null : '/splash';
      if (s.user == null) return _publicRoutes.contains(loc) ? null : '/welcome';
      final p = s.profile;
      if (p != null && !p.onboarded) return loc == '/setup' ? null : '/setup';
      if (_publicRoutes.contains(loc) || loc == '/splash' || (loc == '/setup' && p?.onboarded == true)) return '/';
      if (loc.startsWith('/admin') && p?.isAdmin != true) return '/'; // qulaylik; haqiqiy himoya serverda
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: LoadingView())),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/reset', builder: (_, __) => const ResetScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const ProfileSetupScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/market', builder: (_, __) => const MarketScreen()),
          GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/warehouses', builder: (_, __) => const WarehousesScreen()),
      GoRoute(path: '/warehouse/:id', builder: (_, state) => WarehouseDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/inquiries', builder: (_, __) => const InquiriesScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/assistant', builder: (_, __) => const AssistantScreen()),
      GoRoute(path: '/my-products', builder: (_, __) => const MyProductsScreen()),
      GoRoute(path: '/my-products/new', builder: (_, __) => const ProductFormScreen()),
      GoRoute(path: '/my-products/edit/:id', builder: (_, state) => ProductFormScreen(id: state.pathParameters['id'])),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/categories', builder: (_, __) => const AdminCategoriesScreen()),
      GoRoute(path: '/admin/banners', builder: (_, __) => const AdminMediaScreen(kind: 'banners')),
      GoRoute(path: '/admin/ads', builder: (_, __) => const AdminMediaScreen(kind: 'ads')),
      GoRoute(path: '/admin/settings', builder: (_, __) => const AdminSettingsScreen()),
      GoRoute(path: '/admin/reports', builder: (_, __) => const AdminReportsScreen()),
      GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
      GoRoute(path: '/admin/moderation', builder: (_, __) => const AdminModerationScreen()),
      GoRoute(path: '/product/:id', builder: (_, state) => ProductDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
