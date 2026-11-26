import 'package:flutter/material.dart';

/// The five supported waste classes. Order matches the classifier labels.
enum WasteCategory {
  plastic(Icons.local_drink, Color(0xFF2E86C1)),
  metal(Icons.build_circle, Color(0xFF7F8C8D)),
  glass(Icons.wine_bar, Color(0xFF16A085)),
  paper(Icons.description, Color(0xFFD4A017)),
  organic(Icons.eco, Color(0xFF6D4C41));

  final IconData icon;
  final Color binColor;
  const WasteCategory(this.icon, this.binColor);

  String get key => name;
}
