class Profile {
  final String id;
  final String fullName;
  final String role; // farmer | buyer | warehouse_owner | admin
  final String language;
  final String? region;
  final bool onboarded;
  const Profile({required this.id, required this.fullName, required this.role,
    required this.language, this.region, required this.onboarded});

  bool get isAdmin => role == 'admin';

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        fullName: (m['full_name'] as String?) ?? '',
        role: (m['role'] as String?) ?? 'farmer',
        language: (m['language'] as String?) ?? 'uz',
        region: m['region'] as String?,
        onboarded: (m['onboarded'] as bool?) ?? false,
      );
}
