import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../services/lost_photo.dart';
import '../../services/scan_history.dart';
import '../../services/siglip_classifier.dart';
import '../../services/waste_classifier.dart';

class ScannerScreen extends StatefulWidget {
  final WasteClassifier? classifier;
  final ScanHistory? history;

  /// Shows the opt-in switch for the experimental scanner. True only in a build made for that trial.
  final bool experimentalAvailable;

  /// Builds the experimental scanner (tests inject a fake).
  final WasteClassifier Function()? experimentalFactory;
  const ScannerScreen({super.key, this.classifier, this.history, this.experimentalAvailable = experimentalSiglipBuild, this.experimentalFactory});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final WasteClassifier _standard = widget.classifier ?? OnnxWasteClassifier();
  late WasteClassifier _classifier = _standard;
  FallbackWasteClassifier? _fallback;
  bool _experimental = false;
  static const _prefKey = 'experimentalScanner';
  late final ScanHistory _history = widget.history ?? ScanHistory();
  List<ScanEntry> _entries = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _history.load().then((l) {
      if (mounted) setState(() => _entries = l);
    });
    _startup();
  }

  /// The saved experimental choice is applied BEFORE a photo recovered after an Android kill is classified.
  Future<void> _startup() async {
    if (widget.experimentalAvailable) await _loadExperimentalPref();
    await _recoverLostPhoto();
  }

  Future<void> _loadExperimentalPref() async {
    try {
      final on = (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false;
      if (on && mounted) _setExperimental(true, save: false);
    } catch (_) {}
  }

  void _setExperimental(bool on, {bool save = true}) {
    setState(() {
      _experimental = on;
      _result = null;
      if (on) {
        final fb = FallbackWasteClassifier(widget.experimentalFactory?.call() ?? SiglipWasteClassifier(), _standard);
        _fallback = fb;
        _classifier = fb;
      } else {
        _fallback?.releasePrimary();
        _fallback = null;
        _classifier = _standard;
      }
    });
    if (save) {
      SharedPreferences.getInstance().then((p) => p.setBool(_prefKey, on)).catchError((_) => false);
    }
  }

  /// On low-memory Android phones the system can kill this app while the camera
  /// is open. The photo is then handed back on the next start, so classify it.
  Future<void> _recoverLostPhoto() async {
    try {
      final file = await LostPhoto.recover('scanner');
      if (file == null || !mounted) return;
      await _classifyFile(file);
    } catch (_) {}
  }
  Uint8List? _bytes;
  ScanResult? _result;
  String? _manual; // user's own choice after an experimental unknown / organic result
  String? _error;
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await LostPhoto.mark('scanner');
      final f = await _picker.pickImage(source: source, maxWidth: 1024);
      await LostPhoto.clear();
      if (f == null) {
        setState(() => _busy = false);
        return;
      }
      await _classifyFile(f);
    } catch (e) {
      setState(() {
        _error = e is ExperimentalBusy ? 'experimentalBusy' : 'scanFailed';
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    // Stop and free the experimental session when the screen goes away; an unfinished native run keeps ownership
    // (see SiglipWasteClassifier.nativeMayStillRun) so a recreated screen cannot start a second session on top.
    _fallback?.releasePrimary();
    super.dispose();
  }

  Future<void> _classifyFile(XFile f) async {
    final bytes = await f.readAsBytes();
    final res = await _classifier.classify(bytes);
    await _history.add(ScanEntry(DateTime.now(), res.label, res.hasProbability ? res.topConfidence : -1));
    final entries = await _history.load();
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _result = res;
      _manual = null;
      _entries = entries;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('scanner'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_bytes!, height: 220, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: Text(s.t('scanCamera')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: Text(s.t('scanGallery')),
              ),
            ),
          ]),
          if (widget.experimentalAvailable)
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: SwitchListTile(
                key: const Key('experimentalSwitch'),
                title: Text(s.t('experimentalTitle')),
                subtitle: Text(s.t('experimentalBody'), style: const TextStyle(fontSize: 12)),
                value: _experimental,
                onChanged: _busy ? null : (v) => _setExperimental(v),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              key: const Key('organicLimit'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade700)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(s.t('organicLimit'), style: const TextStyle(fontSize: 12.5))),
              ]),
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
          if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(s.t(_error!), style: const TextStyle(color: Colors.red))),
          if (r != null) ...[
            const SizedBox(height: 16),
            if (r.engine == 'experimental')
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s.t('experimentalResult'), key: const Key('experimentalResult'), style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600))),
            if (_experimental && r.engine == 'standard' && (_fallback?.lastUsedFallback ?? false))
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s.t('experimentalFallback'), key: const Key('experimentalFallback'), style: TextStyle(color: Colors.red.shade800))),
            _ResultCard(result: r),
            if (r.engine == 'experimental' && (r.isUnknown || r.organicUnsupported)) _ManualPick(chosen: _manual, onPick: (v) => setState(() => _manual = v)),
            const SizedBox(height: 12),
            if (r.hasProbability) ...r.probabilities.entries.map((e) => _Bar(label: s.t('model_${e.key}'), value: e.value)),
          ],
          if (_entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(s.t('scanHistory'), style: Theme.of(context).textTheme.titleSmall)),
              TextButton(key: const Key('clearHistory'), onPressed: () async {
                await _history.clear();
                if (mounted) setState(() => _entries = []);
              }, child: Text(s.t('clearHistory'))),
            ]),
            for (final e in _entries)
              ListTile(
                dense: true,
                key: const Key('historyRow'),
                leading: const Icon(Icons.history),
                title: Text(e.label == null ? s.t('unknown') : s.t('model_${e.label}')),
                subtitle: Text('${e.confidence < 0 ? '' : '${(e.confidence * 100).toStringAsFixed(0)}%  •  '}${e.at.toIso8601String().substring(0, 16).replaceAll('T', ' ')}', textDirection: TextDirection.ltr),
              ),
          ],
          const SizedBox(height: 16),
          Text(s.t('scanLimits'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ScanResult result;
  const _ResultCard({required this.result});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pct = '\u2066${(result.topConfidence * 100).toStringAsFixed(0)}%\u2069'; // isolate so '100%' keeps its order in RTL
    String title;
    String body;
    if (result.organicUnsupported) {
      title = s.t('organicUnsupportedTitle');
      body = s.t('organicUnsupportedBody');
    } else if (result.engine == 'experimental' && result.isUnknown) {
      title = s.t('unknown');
      body = s.t('experimentalUnknownBody');
    } else if (result.engine == 'experimental') {
      title = result.bin == null ? s.t('notRecyclableClass') : '${s.t(result.bin!)}: ${s.t('binHint')}';
      body = result.bin == null ? s.t('notRecyclableBody') : s.t('experimentalScore');
    } else if (result.isUnknown) {
      title = s.t('unknown');
      body = '${s.t('unknownBody')} ($pct)';
    } else if (result.label == 'organic') {
      title = s.t('model_organic');
      body = '${s.t('organicResultBody')} ($pct)';
    } else if (result.bin == null) {
      title = s.t('notRecyclableClass');
      body = '${s.t('notRecyclableBody')} ($pct)';
    } else {
      title = '${s.t(result.bin!)}: ${s.t('binHint')}';
      body = '${s.t('confidence')}: $pct';
    }
    return Card(
      key: const Key('resultCard'),
      color: result.organicUnsupported ? Colors.amber.shade50 : AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(body),
        ]),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  const _Bar({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(child: LinearProgressIndicator(value: value, minHeight: 8)),
          SizedBox(width: 48, child: Text('${(value * 100).toStringAsFixed(0)}%', textAlign: TextAlign.end)),
        ]),
      );
}

class _ManualPick extends StatelessWidget {
  final String? chosen;
  final ValueChanged<String> onPick;
  const _ManualPick({required this.chosen, required this.onPick});
  static const _options = ['plastic', 'metal', 'glass', 'paper', 'cardboard', 'organic', 'other'];
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String name(String k) => switch (k) { 'organic' => s.t('model_organic'), 'cardboard' => s.t('model_cardboard'), 'other' => s.t('manualOther'), _ => s.t(k) };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t('manualPickTitle'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final o in _options)
            ChoiceChip(key: Key('manual_$o'), label: Text(name(o)), selected: chosen == o, onSelected: (_) => onPick(o)),
        ]),
        if (chosen != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              chosen == 'organic'
                  ? '${s.t('manualChosen')}: ${name(chosen!)}. ${s.t('manualOrganicNote')}'
                  : chosen == 'other'
                      ? '${s.t('manualChosen')}: ${name(chosen!)}'
                      : '${s.t('manualChosen')}: ${name(chosen!)}. ${s.t('binHint')}',
              key: const Key('manualChosen'),
            ),
          ),
      ]),
    );
  }
}
