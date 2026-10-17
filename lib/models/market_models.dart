class Product {
  final String id, title, category, productType, currency, unit, region, sellerId;
  final double price, quantity;
  final String? description, imageUrl;
  final DateTime createdAt;
  final List<String> images;
  const Product({required this.id, required this.title, required this.category, required this.productType,
    required this.currency, required this.unit, required this.region, required this.sellerId, required this.price,
    required this.quantity, this.description, this.imageUrl, required this.createdAt, this.images = const []});

  factory Product.fromMap(Map<String, dynamic> m) {
    final imgs = (m['product_images'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    imgs.sort((a, b) => ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
    final main = m['image_url'] as String?;
    final urls = [if (main != null) main, ...imgs.map((e) => e['url'] as String).where((u) => u != main)];
    return Product(
      id: m['id'] as String, title: m['title'] as String, category: m['category'] as String,
      productType: (m['product_type'] as String?) ?? '', currency: m['currency'] as String, unit: m['unit'] as String,
      region: m['region'] as String, sellerId: m['seller_id'] as String, price: (m['price'] as num).toDouble(),
      quantity: (m['quantity'] as num).toDouble(), description: m['description'] as String?, imageUrl: main,
      createdAt: DateTime.parse(m['created_at'] as String), images: urls);
  }
}

class Category {
  final String slug, nameUz, nameRu, nameEn;
  final String? icon;
  const Category(this.slug, this.nameUz, this.nameRu, this.nameEn, this.icon);
  factory Category.fromMap(Map<String, dynamic> m) => Category(m['slug'] as String, m['name_uz'] as String,
      m['name_ru'] as String, m['name_en'] as String, m['icon'] as String?);
  String name(String lang) => lang == 'ru' ? nameRu : lang == 'en' ? nameEn : nameUz;
}

class BannerItem {
  final String id, title, imageUrl, linkType;
  final String? subtitle, linkValue;
  const BannerItem(this.id, this.title, this.subtitle, this.imageUrl, this.linkType, this.linkValue);
  factory BannerItem.fromMap(Map<String, dynamic> m) => BannerItem(m['id'] as String, m['title'] as String,
      m['subtitle'] as String?, m['image_url'] as String, (m['link_type'] as String?) ?? 'none', m['link_value'] as String?);
}

class ProductFilters {
  final String query, region, currency, sort; // sort: new | price_asc | price_desc
  final String? category;
  final double? minPrice, maxPrice;
  const ProductFilters({this.query = '', this.region = '', this.currency = 'UZS', this.sort = 'new',
    this.category, this.minPrice, this.maxPrice});

  bool get hasActive => category != null || region.isNotEmpty || minPrice != null || maxPrice != null || sort != 'new';

  ProductFilters copyWith({String? query, String? region, String? currency, String? sort,
      Object? category = _keep, Object? minPrice = _keep, Object? maxPrice = _keep}) =>
      ProductFilters(query: query ?? this.query, region: region ?? this.region, currency: currency ?? this.currency,
        sort: sort ?? this.sort, category: identical(category, _keep) ? this.category : category as String?,
        minPrice: identical(minPrice, _keep) ? this.minPrice : minPrice as double?,
        maxPrice: identical(maxPrice, _keep) ? this.maxPrice : maxPrice as double?);
}

const Object _keep = Object();
