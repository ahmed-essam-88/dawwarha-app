import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_theme.dart';

/// Honest placeholder for modules that are not built yet.
class ComingSoon extends StatelessWidget {
  final String titleKey;
  const ComingSoon({super.key, required this.titleKey});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t(titleKey))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 56, color: AppColors.secondary),
              const SizedBox(height: 12),
              Text(s.t('comingSoon'), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
