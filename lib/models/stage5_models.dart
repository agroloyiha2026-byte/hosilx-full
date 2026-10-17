class Warehouse {
  final String id, name, region, storageType, currency, ownerId;
  final double capacityTons, freeTons;
  final double? pricePerTonMonth;
  final String? address, conditions, contactPhone, imageUrl;
  final List<String> accepted;
  const Warehouse({required this.id, required this.name, required this.region, required this.storageType,
    required this.currency, required this.ownerId, required this.capacityTons, required this.freeTons,
    this.pricePerTonMonth, this.address, this.conditions, this.contactPhone, this.imageUrl, this.accepted = const []});

  factory Warehouse.fromMap(Map<String, dynamic> m) => Warehouse(
        id: m['id'] as String, name: m['name'] as String, region: m['region'] as String,
        storageType: m['storage_type'] as String, currency: (m['currency'] as String?) ?? 'UZS', ownerId: m['owner_id'] as String,
        capacityTons: (m['capacity_tons'] as num).toDouble(), freeTons: (m['free_tons'] as num).toDouble(),
        pricePerTonMonth: (m['price_per_ton_month'] as num?)?.toDouble(), address: m['address'] as String?,
        conditions: m['conditions'] as String?, contactPhone: m['contact_phone'] as String?, imageUrl: m['image_url'] as String?,
        accepted: ((m['accepted_products'] as List?) ?? const []).cast<String>());
}

class InquiryItem {
  final String id, status, buyerId, productTitle, sellerId, currency;
  final double? offeredPrice;
  final String? message;
  final DateTime createdAt;
  const InquiryItem({required this.id, required this.status, required this.buyerId, required this.productTitle,
    required this.sellerId, required this.currency, this.offeredPrice, this.message, required this.createdAt});

  factory InquiryItem.fromMap(Map<String, dynamic> m) {
    final p = (m['products'] as Map<String, dynamic>?) ?? const {};
    return InquiryItem(id: m['id'] as String, status: m['status'] as String, buyerId: m['buyer_id'] as String,
        productTitle: (p['title'] as String?) ?? '—', sellerId: (p['seller_id'] as String?) ?? '', currency: (p['currency'] as String?) ?? '',
        offeredPrice: (m['offered_price'] as num?)?.toDouble(), message: m['message'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String));
  }
}

class NotificationItem {
  final String id, type, titleKey;
  final String? body, productId;
  final bool read;
  final DateTime createdAt;
  const NotificationItem({required this.id, required this.type, required this.titleKey, this.body, this.productId,
    required this.read, required this.createdAt});

  factory NotificationItem.fromMap(Map<String, dynamic> m) => NotificationItem(
        id: m['id'] as String, type: m['type'] as String, titleKey: m['title'] as String, body: m['body'] as String?,
        productId: (m['data'] as Map?)?['product_id'] as String?, read: m['read'] as bool, createdAt: DateTime.parse(m['created_at'] as String));
}
