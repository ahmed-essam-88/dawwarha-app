import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/recycling_center.dart';

abstract class CentersRepository {
  Future<List<RecyclingCenter>> fetch();
}

/// Reads the editable data file assets/data/centers.json. No invented places: every row needs a source.
class AssetCentersRepository implements CentersRepository {
  final Future<String> Function() load;
  AssetCentersRepository({Future<String> Function()? load}) : load = load ?? (() => rootBundle.loadString('assets/data/centers.json'));
  @override
  Future<List<RecyclingCenter>> fetch() async {
    final rows = jsonDecode(await load()) as List;
    return [for (var i = 0; i < rows.length; i++) RecyclingCenter.fromJson(rows[i] as Map<String, dynamic>, i)];
  }
}
