import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../domain/core.dart';
import '../domain/models.dart';

/// Local profiles + Microsoft account orchestration.
/// No passwords are ever requested or stored; tokens live in secure storage.
class AccountService {
  AccountService(this.core);
  final NovaCore core;

  final FlutterSecureStorage secure = const FlutterSecureStorage();

  Future<List<UserProfile>> list() => core.db.profiles();

  Future<UserProfile> createLocal(String name) async {
    final pr = UserProfile(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: 'local',
      isDefault: (await core.db.profiles()).isEmpty,
    );
    await core.db.saveProfile(pr);
    return pr;
  }

  Future<void> rename(UserProfile pr, String name) =>
      core.db.saveProfile(pr.copyWith(name: name));

  Future<void> setDefault(UserProfile pr) =>
      core.db.saveProfile(pr.copyWith(isDefault: true));

  Future<void> remove(UserProfile pr) => core.db.deleteProfile(pr.id);

  /// Stores a skin PNG chosen from the device into the app's skins dir.
  Future<String> importSkin(String srcPath) async {
    final dest = File(p.join(
        core.paths.skins,
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(srcPath)}'));
    await File(srcPath).copy(dest.path);
    return dest.path;
  }

  Future<void> setSkin(UserProfile pr, String? skinPath, {String model = 'classic'}) =>
      core.db.saveProfile(pr.copyWith(skinPath: skinPath, skinModel: model));

  // Secure token storage (Microsoft refresh flow).
  Future<void> storeMsToken(String token) =>
      secure.write(key: 'ms_token', value: token);

  Future<String?> readMsToken() => secure.read(key: 'ms_token');

  Future<void> clearMsToken() => secure.delete(key: 'ms_token');
}
