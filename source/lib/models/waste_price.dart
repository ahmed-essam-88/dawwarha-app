class WastePrice {
  final String material; // plastic, metal, paper, glass, other
  final String itemEn, itemAr;
  final double minPerKg, maxPerKg;
  final String currency;
  final DateTime updatedAt;
  final String source;
  final String sourceAr;
  final String? sourceUrl;
  final double? points; // buyer's reward points per kg, shown separately from cash
  final bool unitUnspecified; // true when the source does not state the unit: shown without '/ kg'
  final bool dateIsAccess; // true when the page prints no date and updatedAt is the day it was read
  const WastePrice(this.material, this.itemEn, this.itemAr, this.minPerKg, this.maxPerKg, this.currency, this.updatedAt, this.source, [this.sourceUrl, String? sourceAr, this.points, this.dateIsAccess = false, this.unitUnspecified = false]) : sourceAr = sourceAr ?? source;

  /// Every price needs a source and a date; a row without them is rejected, not shown.
  factory WastePrice.fromJson(Map<String, dynamic> j) {
    final source = (j['source'] as String?)?.trim() ?? '';
    final updated = DateTime.tryParse((j['updated'] as String?) ?? '');
    final min = (j['min'] as num?)?.toDouble();
    final max = (j['max'] as num?)?.toDouble() ?? min;
    if (source.isEmpty || updated == null || min == null || max == null || min < 0 || max < min) {
      throw const FormatException('price row needs source, date and a valid range');
    }
    return WastePrice(j['material'] as String, (j['item_en'] as String?) ?? (j['material'] as String), (j['item_ar'] as String?) ?? (j['material'] as String),
        min, max, (j['currency'] as String?) ?? 'EGP', updated, source, j['source_url'] as String?, j['source_ar'] as String?, (j['points'] as num?)?.toDouble(), (j['date_is_access'] as bool?) ?? false, (j['unit'] as String?) == 'unspecified');
  }

  String get rangeText => minPerKg == maxPerKg ? _n(minPerKg) : '${_n(minPerKg)} - ${_n(maxPerKg)}';
  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
