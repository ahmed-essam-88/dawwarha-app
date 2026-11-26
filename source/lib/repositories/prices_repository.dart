import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/waste_price.dart';

abstract class PricesRepository {
  Future<List<WastePrice>> fetch();
}

/// Reads the editable data file assets/data/prices.json. Every row carries its source and date.
/// There are no built-in fallback values: missing rows stay missing.
class AssetPricesRepository implements PricesRepository {
  final Future<String> Function() load;
  AssetPricesRepository({Future<String> Function()? load}) : load = load ?? (() => rootBundle.loadString('assets/data/prices.json'));
  @override
  Future<List<WastePrice>> fetch() async =>
      (jsonDecode(await load()) as List).map((e) => WastePrice.fromJson(e as Map<String, dynamic>)).toList();
}
