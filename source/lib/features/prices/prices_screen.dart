import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/waste_price.dart';
import '../../providers/locale_provider.dart';
import '../../repositories/prices_repository.dart';

const _categories = ['plastic', 'metal', 'paper', 'glass', 'other'];

class PricesScreen extends StatefulWidget {
  /// Injected in tests; defaults to the editable data file.
  final PricesRepository? repository;
  const PricesScreen({super.key, this.repository});
  @override
  State<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends State<PricesScreen> {
  late final Future<List<WastePrice>> _future =
      (widget.repository ?? AssetPricesRepository()).fetch();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ar = context.watch<LocaleProvider>().isArabic;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('prices'))),
      body: FutureBuilder<List<WastePrice>>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(s.t('pricesError'), textAlign: TextAlign.center),
              ),
            );
          final list = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                s.t('pricesNote'),
                style: const TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final cat in _categories) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    s.t(cat),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!list.any((p) => p.material == cat) && cat == 'other')
                  const SizedBox.shrink()
                else if (!list.any((p) => p.material == cat))
                  Card(
                    child: ListTile(
                      key: Key('none_$cat'),
                      leading: const Icon(Icons.info_outline),
                      title: Text(s.t('noSourcedPrice')),
                    ),
                  )
                else
                  for (final p in list.where((p) => p.material == cat))
                    Card(
                      child: ListTile(
                        key: Key('price_${p.material}_${p.itemEn}'),
                        title: Text(ar ? p.itemAr : p.itemEn),
                        subtitle: Text(
                          '${s.t(p.dateIsAccess ? 'accessed' : 'updated')}: ${p.updatedAt.toIso8601String().substring(0, 10)}\n${s.t('sourceLabel')}: ${ar ? p.sourceAr : p.source}${p.points == null ? '' : '\n${s.t('points')}: ${p.points! == p.points!.roundToDouble() ? p.points!.toStringAsFixed(0) : p.points!.toStringAsFixed(1)}'}',
                        ),
                        isThreeLine: true,
                        trailing: SizedBox(
                          width: 92,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // the whole range is one left-to-right segment so min stays before max
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    p.rangeText,
                                    key: Key('range_${p.itemEn}'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  p.unitUnspecified
                                      ? '${ar && p.currency == 'EGP' ? 'ج.م' : p.currency}\n${s.t('unitUnspecified')}'
                                      : '${ar && p.currency == 'EGP' ? 'ج.م' : p.currency} / ${s.t('kg')}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        leading: p.sourceUrl == null
                            ? null
                            : const Icon(Icons.open_in_new, size: 18),
                        onTap: p.sourceUrl == null
                            ? null
                            : () => launchUrl(
                                Uri.parse(p.sourceUrl!),
                                mode: LaunchMode.externalApplication,
                              ),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}
