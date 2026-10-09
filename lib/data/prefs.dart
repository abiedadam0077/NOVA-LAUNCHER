import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// App-level settings persisted locally (offline-first).
class NovaPrefs {
  SharedPreferences? _p;

  Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get p {
    final s = _p;
    if (s == null) throw StateError('NovaPrefs not initialized');
    return s;
  }

  static const kLocale = 'locale';
  static const kPerfProfile = 'perfProfile';
  static const kSelectedVersion = 'selectedVersion';
  static const kSelectedLoader = 'selectedLoader';
  static const kMsClientId = 'msClientId';
  static const kReducedMotion = 'reducedMotion';
  static const kRenderDistance = 'renderDistance';
  static const kSimDistance = 'simDistance';
  static const kRamMb = 'ramMb';
  static const kJvmArgs = 'jvmArgs';

  String get locale => p.getString(kLocale) ?? 'en';
  Future<void> setLocale(String v) => p.setString(kLocale, v);

  PerfProfileId get perfProfile => PerfProfileId.values.firstWhere(
        (e) => e.name == (p.getString(kPerfProfile) ?? 'balanced'),
        orElse: () => PerfProfileId.balanced,
      );
  Future<void> setPerfProfile(PerfProfileId v) => p.setString(kPerfProfile, v.name);

  String? get selectedVersion => p.getString(kSelectedVersion);
  Future<void> setSelectedVersion(String v) => p.setString(kSelectedVersion, v);

  LoaderType get selectedLoader => LoaderType.values.firstWhere(
        (e) => e.name == (p.getString(kSelectedLoader) ?? 'vanilla'),
        orElse: () => LoaderType.vanilla,
      );
  Future<void> setSelectedLoader(LoaderType v) =>
      p.setString(kSelectedLoader, v.name);

  String? get msClientId => p.getString(kMsClientId);
  Future<void> setMsClientId(String v) => p.setString(kMsClientId, v);

  bool get reducedMotion => p.getBool(kReducedMotion) ?? false;
  Future<void> setReducedMotion(bool v) => p.setBool(kReducedMotion, v);
}
