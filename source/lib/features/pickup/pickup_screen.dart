import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/lost_photo.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pickup_request.dart';
import '../../providers/locale_provider.dart';
import '../../services/location_service.dart';

const _mats = ['plastic', 'metal', 'glass', 'paper', 'organic'];

class PickupScreen extends StatefulWidget {
  final LocationService? location;
  final Future<bool> Function(Uri)? launcher;
  final Future<String?> Function(ImageSource)? pickImage; // returns a file path; injected in tests
  final Future<void> Function(String text, String? imagePath)? shareSheet;
  const PickupScreen({super.key, this.location, this.launcher, this.pickImage, this.shareSheet});
  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  final _items = TextEditingController();
  final _kg = TextEditingController();
  final _phone = TextEditingController();
  String _material = 'plastic';
  DateTime? _when;
  UserPosition? _pos;
  String? _imagePath;
  String? _error; // string key

  PickupRequest _build() => PickupRequest(
      material: _material,
      items: int.tryParse(_items.text.trim()),
      kg: double.tryParse(_kg.text.trim().replaceAll(',', '.')),
      phone: _phone.text,
      when: _when,
      lat: _pos?.lat,
      lon: _pos?.lon);

  String? _validate() => PickupRequest.validate(itemsText: _items.text, kgText: _kg.text, phone: _phone.text);

  Future<void> _useLocation() async {
    try {
      final p = await (widget.location ?? DeviceLocationService()).current();
      setState(() {
        _pos = p;
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'locFailed');
    }
  }

  @override
  void initState() {
    super.initState();
    _recoverLostPhoto();
  }

  /// See LostPhoto: only the screen that opened the camera gets its photo back.
  Future<void> _recoverLostPhoto() async {
    final file = await LostPhoto.recover('pickup');
    if (file != null && mounted) setState(() => _imagePath = file.path);
  }

  Future<void> _photo(ImageSource src) async {
    try {
      if (widget.pickImage == null) await LostPhoto.mark('pickup');
      final path = widget.pickImage != null ? await widget.pickImage!(src) : (await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85))?.path;
      if (widget.pickImage == null) await LostPhoto.clear();
      if (path != null) setState(() => _imagePath = path);
    } catch (_) {
      setState(() => _error = 'photoFailed');
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _when ?? now, firstDate: now, lastDate: now.add(const Duration(days: 90)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when ?? now));
    if (t == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  String _text() {
    final s = S(context.read<LocaleProvider>().isArabic);
    return _build().shareText(materialLabel: s.t(_material), labels: {
      'material': s.t('material'),
      'items': s.t('itemCount'),
      'kg': s.t('weightKg'),
      'time': s.t('prefTime'),
      'phone': s.t('phone'),
      'location': s.t('locationLabel'),
    });
  }

  Future<void> _launch(Uri u) async {
    final ok = await (widget.launcher ?? (x) => launchUrl(x, mode: LaunchMode.externalApplication))(u);
    if (!ok && mounted) setState(() => _error = 'navFailed');
  }

  Future<void> _share(String kind) async {
    final v = _validate();
    if (v != null) return setState(() => _error = v);
    setState(() => _error = null);
    final text = _text();
    switch (kind) {
      case 'wa':
        await _launch(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'));
      case 'sms':
        // Percent-encode (%20), not form-encode (+): SMS apps show a literal + otherwise.
        await _launch(Uri.parse('sms:?body=${Uri.encodeComponent(text)}'));
      default:
        try {
          if (widget.shareSheet != null) {
            await widget.shareSheet!(text, _imagePath);
          } else {
            await SharePlus.instance.share(ShareParams(text: text, files: _imagePath == null ? null : [XFile(_imagePath!)]));
          }
        } catch (_) {
          if (mounted) setState(() => _error = 'navFailed');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final valid = _validate() == null;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('tabPickup'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(s.t('pickupIntro')),
        const SizedBox(height: 12),
        if (_imagePath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_imagePath!), key: const Key('photoPreview'), height: 160, fit: BoxFit.cover, errorBuilder: (c, e, st) => const SizedBox(height: 60, child: Icon(Icons.image)))),
          ),
        Row(children: [
          Expanded(child: OutlinedButton.icon(key: const Key('takePhoto'), onPressed: () => _photo(ImageSource.camera), icon: const Icon(Icons.photo_camera), label: Text(s.t('takePhoto')))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(key: const Key('pickPhoto'), onPressed: () => _photo(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: Text(s.t('choosePhoto')))),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('material'),
          initialValue: _material,
          decoration: InputDecoration(labelText: s.t('material')),
          items: [for (final m in _mats) DropdownMenuItem(value: m, child: Text(s.t(m)))],
          onChanged: (v) => setState(() => _material = v!),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(key: const Key('items'), controller: _items, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: s.t('itemCount')))),
          const SizedBox(width: 8),
          Expanded(child: TextField(key: const Key('kg'), controller: _kg, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: s.t('weightKg')))),
        ]),
        TextField(key: const Key('phone'), controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: s.t('phone'))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            key: const Key('pickTime'),
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule),
            label: Text(_when == null ? s.t('prefTime') : '${_when!.year}-${_when!.month.toString().padLeft(2, '0')}-${_when!.day.toString().padLeft(2, '0')} ${_when!.hour.toString().padLeft(2, '0')}:${_when!.minute.toString().padLeft(2, '0')}')),
        OutlinedButton.icon(key: const Key('useLoc'), onPressed: _useLocation, icon: const Icon(Icons.my_location), label: Text(_pos == null ? s.t('useLocation') : s.t('locationAdded'))),
        if (_pos != null)
          Padding(
            key: const Key('coords'),
            padding: const EdgeInsets.only(top: 6),
            child: Column(children: [
              for (final e in [(s.t('latitude'), _pos!.lat), (s.t('longitude'), _pos!.lon)])
                Row(children: [
                  Expanded(child: Text(e.$1)),
                  Directionality(textDirection: TextDirection.ltr, child: Text(e.$2.toStringAsFixed(6), style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
            ]),
          ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.t(_error!), key: const Key('pickup_error'), style: TextStyle(color: Colors.red.shade800))),
        const SizedBox(height: 12),
        if (valid)
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.t('reviewTitle'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(_text(), key: const Key('preview'), textDirection: TextDirection.ltr),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton.icon(key: const Key('shareSms'), onPressed: () => _share('sms'), icon: const Icon(Icons.sms), label: const Text('SMS'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.icon(key: const Key('shareWa'), onPressed: () => _share('wa'), icon: const Icon(Icons.chat), label: const Text('WhatsApp'))),
        ]),
        if (_imagePath != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.icon(key: const Key('shareSheet'), onPressed: () => _share('sheet'), icon: const Icon(Icons.share), label: Text(s.t('shareWithPhoto'))),
          ),
        const SizedBox(height: 4),
        Text(s.t('shareNote'), style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
      ]),
    );
  }
}
