import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/edu_content.dart';
import '../../providers/locale_provider.dart';
import 'education_data.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('education'))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: eduContents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final c = eduContents[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: c.category.binColor.withOpacity(0.15),
                child: Icon(c.category.icon, color: c.category.binColor),
              ),
              title: Text(s.t(c.category.key),
                  style: Theme.of(context).textTheme.titleMedium),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EducationDetailScreen(content: c))),
            ),
          );
        },
      ),
    );
  }
}

class EducationDetailScreen extends StatelessWidget {
  final EduContent content;
  const EducationDetailScreen({super.key, required this.content});

  static const _sections = [
    'description', 'examples', 'process', 'sorting',
    'benefits', 'mistakes', 'tips',
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final data = content.forLang(context.watch<LocaleProvider>().isArabic);
    final cat = content.category;
    return Scaffold(
      appBar: AppBar(title: Text(s.t(cat.key))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: cat.binColor.withOpacity(0.15),
              child: Icon(cat.icon, size: 44, color: cat.binColor),
            ),
          ),
          const SizedBox(height: 16),
          for (final key in _sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t(key),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.primary)),
                      const SizedBox(height: 8),
                      for (final line in data[key] ?? const <String>[])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                              key == 'description' ? line : '\u2022 $line'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
