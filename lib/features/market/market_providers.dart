import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/market_models.dart';
import '../auth/session_controller.dart';
import 'market_repository.dart';

final marketRepositoryProvider = Provider<MarketRepository>((ref) => MarketRepository());

final categoriesProvider = FutureProvider<List<Category>>((ref) => ref.read(marketRepositoryProvider).categories());
final bannersProvider = FutureProvider<List<BannerItem>>((ref) => ref.read(marketRepositoryProvider).banners());
final recentProductsProvider =
    FutureProvider<List<Product>>((ref) => ref.read(marketRepositoryProvider).products(const ProductFilters(), 0, 8));

final filtersProvider = StateProvider<ProductFilters>((ref) => const ProductFilters());

class PagedProducts {
  final List<Product> items;
  final bool loading, hasMore;
  final Object? error;
  const PagedProducts({this.items = const [], this.loading = false, this.hasMore = true, this.error});
}

class ProductsController extends StateNotifier<PagedProducts> {
  static const _size = 20;
  final MarketRepository _repo;
  final ProductFilters _f;
  int _page = 0;
  ProductsController(this._repo, this._f) : super(const PagedProducts(loading: true)) {
    refresh();
  }

  Future<void> refresh() async {
    _page = 0;
    state = const PagedProducts(loading: true);
    try {
      final items = await _repo.products(_f, 0, _size);
      if (mounted) state = PagedProducts(items: items, hasMore: items.length == _size);
    } catch (e) {
      if (mounted) state = PagedProducts(error: e, hasMore: false);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.error != null) return;
    state = PagedProducts(items: state.items, loading: true, hasMore: true);
    try {
      final more = await _repo.products(_f, _page + 1, _size);
      _page++;
      if (mounted) state = PagedProducts(items: [...state.items, ...more], hasMore: more.length == _size);
    } catch (e) {
      if (mounted) state = PagedProducts(items: state.items, error: e, hasMore: false);
    }
  }
}

/// Filtr o'zgarganda controller qayta yaratiladi va ro'yxat yangidan yuklanadi.
final productsProvider = StateNotifierProvider.autoDispose<ProductsController, PagedProducts>(
    (ref) => ProductsController(ref.read(marketRepositoryProvider), ref.watch(filtersProvider)));

class FavoritesController extends StateNotifier<Set<String>> {
  final MarketRepository _repo;
  final String? _uid;
  FavoritesController(this._repo, this._uid) : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    if (_uid == null) return;
    try {
      final ids = await _repo.favoriteIds(_uid!);
      if (mounted) state = ids;
    } catch (_) {}
  }

  /// Muvaffaqiyatsiz bo'lsa holatni qaytaradi va xatoni yuqoriga uzatadi.
  Future<void> toggle(String pid) async {
    if (_uid == null) return;
    final prev = state;
    final on = !prev.contains(pid);
    state = on ? {...prev, pid} : ({...prev}..remove(pid));
    try {
      await _repo.setFavorite(_uid!, pid, on);
    } catch (_) {
      if (mounted) state = prev;
      rethrow;
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesController, Set<String>>((ref) =>
    FavoritesController(ref.read(marketRepositoryProvider), ref.watch(sessionProvider.select((s) => s.user?.id))));

final favoriteProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) {
  ref.watch(favoritesProvider);
  return ref.read(marketRepositoryProvider).favorites();
});

class ProductDetail {
  final Product product;
  final String? sellerName, sellerRegion;
  const ProductDetail(this.product, this.sellerName, this.sellerRegion);
}

final productDetailProvider = FutureProvider.autoDispose.family<ProductDetail?, String>((ref, id) async {
  final repo = ref.read(marketRepositoryProvider);
  final p = await repo.product(id);
  if (p == null) return null;
  final s = await repo.seller(p.sellerId);
  return ProductDetail(p, s.name, s.region);
});
