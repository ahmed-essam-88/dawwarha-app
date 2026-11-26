import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android can kill the app while the camera is open. image_picker hands the
/// photo back on the next start, but it does not say which screen asked for
/// it, and it can be fetched only once. So the screen that opens the camera
/// leaves a marker first, and on restart only that screen gets the photo.
class LostPhoto {
  static const _key = 'pendingPhotoOwner';
  static Future<({XFile? file, String? owner})>? _once;

  /// Call right before opening the camera or gallery.
  static Future<void> mark(String owner) async {
    try {
      (await SharedPreferences.getInstance()).setString(_key, owner);
    } catch (_) {}
  }

  /// Call when the picker returned normally (or was cancelled).
  static Future<void> clear() async {
    try {
      (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }

  static Future<({XFile? file, String? owner})> _fetch() async {
    String? owner;
    try {
      owner = (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {}
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (!lost.isEmpty && lost.file != null) {
        await clear();
        return (file: lost.file, owner: owner);
      }
    } catch (_) {}
    return (file: null, owner: owner);
  }

  /// The recovered photo if [owner] opened the picker before the app died.
  static Future<XFile?> recover(String owner) async {
    final r = await (_once ??= _fetch());
    return r.owner == owner ? r.file : null;
  }

  /// Tests only.
  static void reset() => _once = null;
}
