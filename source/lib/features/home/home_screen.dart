import 'package:flutter/material.dart';
import '../game/games_hub.dart';
import '../prices/prices_screen.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/feature_card.dart';
import '../education/education_screen.dart';
import 'daily_tips.dart';

class HomeScreen extends StatelessWidget {
  /// Switches the bottom tab (0 home, 1 scan, 2 map, 3 pickup, 4 profile).
  final ValueChanged<int> onSelectTab;
  const HomeScreen({super.key, required this.onSelectTab});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isAr = context.watch<LocaleProvider>().isArabic;
    final tip = dailyTips[tipIndexFor(DateTime.now())][isAr ? 1 : 0];
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('appName')),
        actions: [
          TextButton(
            onPressed: () => context.read<LocaleProvider>().toggle(),
            child: Text(s.t('language')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.recycling, color: AppColors.primary, size: 34),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('welcome'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(s.t('tagline'),
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(s.t('features'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              FeatureCard(icon: Icons.document_scanner, label: s.t('scanner'), onTap: () => onSelectTab(1)),
              FeatureCard(icon: Icons.menu_book, label: s.t('education'), onTap: () => _open(context, const EducationScreen())),
              FeatureCard(icon: Icons.sports_esports, label: s.t('game'), onTap: () => _open(context, const GamesHub())),
              FeatureCard(icon: Icons.local_shipping, label: s.t('collection'), onTap: () => onSelectTab(3)),
              FeatureCard(icon: Icons.map, label: s.t('map'), onTap: () => onSelectTab(2)),
              FeatureCard(icon: Icons.payments, label: s.t('prices'), onTap: () => _open(context, const PricesScreen())),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.lightbulb, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(s.t('dailyInfo'), style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 8),
                  Text(tip),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.public, color: AppColors.primary),
              title: Text(s.t('awareness'), style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(s.t('tagline')),
            ),
          ),
        ],
      ),
    );
  }
}
