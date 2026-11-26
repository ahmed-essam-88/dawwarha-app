class RecyclingCenter {
  final int id;
  final String name;
  final String? address, phone, hours;
  final double lat;
  final double lon;
  final List<String> materials;
  final String source, sourceAr;
  final String? nameAr, noteEn, noteAr, sourceUrl, addressAr;
  const RecyclingCenter({required this.id, required this.name, required this.lat, required this.lon, this.address, this.phone, this.hours, this.materials = const [], required this.source, String? sourceAr, this.nameAr, this.noteEn, this.noteAr, this.sourceUrl, this.addressAr}) : sourceAr = sourceAr ?? source;

  /// A center needs a name, valid coordinates and a source; a row without them is rejected.
  factory RecyclingCenter.fromJson(Map<String, dynamic> j, int index) {
    final name = (j['name'] as String?)?.trim() ?? '';
    final source = (j['source'] as String?)?.trim() ?? '';
    final lat = (j['lat'] as num?)?.toDouble(), lon = (j['lon'] as num?)?.toDouble();
    if (name.isEmpty || source.isEmpty || lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      throw const FormatException('center row needs name, source and valid coordinates');
    }
    return RecyclingCenter(
        id: index,
        name: name,
        lat: lat,
        lon: lon,
        address: j['address'] as String?,
        addressAr: j['address_ar'] as String?,
        phone: j['phone'] as String?,
        hours: j['hours'] as String?,
        materials: ((j['materials'] as List?) ?? const []).cast<String>(),
        source: source,
        sourceAr: j['source_ar'] as String?,
        nameAr: j['name_ar'] as String?,
        noteEn: j['note_en'] as String?,
        noteAr: j['note_ar'] as String?,
        sourceUrl: j['source_url'] as String?);
  }
}
