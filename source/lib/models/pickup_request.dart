/// A pickup request that the user shares by SMS or WhatsApp. It is not stored or sent
/// anywhere by the app, so nothing here can claim that a collector accepted it.
class PickupRequest {
  final String material;
  final int? items;
  final double? kg;
  final String phone;
  final DateTime? when;
  final double? lat, lon;
  const PickupRequest({required this.material, this.items, this.kg, required this.phone, this.when, this.lat, this.lon});

  /// Returns a validation key (for the UI) or null when valid.
  static String? validate({required String itemsText, required String kgText, required String phone}) {
    final i = itemsText.trim(), k = kgText.trim().replaceAll(',', '.');
    if (i.isEmpty && k.isEmpty) return 'errQuantity';
    if (i.isNotEmpty && (int.tryParse(i) == null || int.parse(i) <= 0 || int.parse(i) > 100000)) return 'errQuantity';
    if (k.isNotEmpty && (double.tryParse(k) == null || double.parse(k) <= 0 || double.parse(k) > 100000)) return 'errQuantity';
    if (!RegExp(r'^\+?[0-9 ]{6,20}$').hasMatch(phone.trim())) return 'errPhone';
    return null;
  }

  static String mapsLink(double lat, double lon) => 'https://www.google.com/maps?q=${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Message text, labels supplied by the caller so it follows the app language.
  String shareText({required String materialLabel, required Map<String, String> labels}) {
    final lines = <String>[
      '${labels['material']}: $materialLabel',
      if (items != null) '${labels['items']}: $items',
      if (kg != null) '${labels['kg']}: ${kg == kg!.roundToDouble() ? kg!.toStringAsFixed(0) : kg}',
      if (when != null) '${labels['time']}: ${when!.year}-${_two(when!.month)}-${_two(when!.day)} ${_two(when!.hour)}:${_two(when!.minute)}',
      '${labels['phone']}: ${phone.trim()}',
      if (lat != null && lon != null) '${labels['location']}: ${mapsLink(lat!, lon!)}',
    ];
    return lines.join('\n');
  }
}
