import '../models/waste_category.dart';

/// Education text for one material, in both languages.
class EduContent {
  final WasteCategory category;
  final Map<String, List<String>> en;
  final Map<String, List<String>> ar;
  const EduContent(this.category, this.en, this.ar);

  Map<String, List<String>> forLang(bool arabic) => arabic ? ar : en;
}
