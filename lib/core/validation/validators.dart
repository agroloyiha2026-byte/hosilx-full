/// Har bir validator xato bo'lsa l10n KALITINI qaytaradi, to'g'ri bo'lsa null.
class Validators {
  static String? required(String? v) => (v == null || v.trim().isEmpty) ? 'v_required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'v_required';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'v_email';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'v_required';
    return v.length < 8 ? 'v_password' : null;
  }

  /// Saqlash so'rovi: miqdor > 0 va bo'sh joydan oshmasin.
  static String? tons(String? v, double free) {
    final n = double.tryParse((v ?? '').replaceAll(' ', '').replaceAll(',', '.'));
    return (n == null || n <= 0 || n > free) ? 'v_tons' : null;
  }

  static String? positive(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(' ', '').replaceAll(',', '.'));
    return (n == null || n <= 0) ? 'v_positive' : null;
  }
}
