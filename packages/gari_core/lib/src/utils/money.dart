String formatBirr(num amount) {
  final n = amount.round();
  final s = n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '$s Br';
}
