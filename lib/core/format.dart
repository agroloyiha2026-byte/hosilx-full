/// 1234567 -> "1 234 567"; kasr qismi bo'lsa 2 xona.
String fmtNum(double v) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final i = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  return parts.length > 1 ? '$i.${parts[1]}' : i;
}
