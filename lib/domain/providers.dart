import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/strings.dart';
import '../data/jsonx.dart';
import 'core.dart';
import 'log_service.dart';
import 'models.dart';
import 'version_service.dart';
import 'mod_service.dart';
import 'map_service.dart';
import 'resource_service.dart';
import 'server_service.dart';
import 'account_service.dart';
import 'performance_service.dart';
import 'runtime_bridge.dart';
import 'modpack_service.dart';

final coreProvider = Provider<NovaCore>((ref) => NovaCore.instance);

final initProvider = FutureProvider<void>((ref) => ref.read(coreProvider).init());

// ------------------------------------------------------------- services
final versionServiceProvider =
    Provider<VersionService>((ref) => VersionService(ref.read(coreProvider)));
final modServiceProvider =
    Provider<ModService>((ref) => ModService(ref.read(coreProvider)));
final mapServiceProvider =
    Provider<MapService>((ref) => MapService(ref.read(coreProvider)));
final resourceServiceProvider =
    Provider<ResourceService>((ref) => ResourceService(ref.read(coreProvider)));
final serverServiceProvider =
    Provider<ServerService>((ref) => ServerService(ref.read(coreProvider)));
final accountServiceProvider =
    Provider<AccountService>((ref) => AccountService(ref.read(coreProvider)));
final perfServiceProvider =
    Provider<PerformanceService>((ref) => PerformanceService(ref.read(coreProvider)));
final runtimeBridgeProvider =
    Provider<RuntimeBridge>((ref) => RuntimeBridge(ref.read(coreProvider)));
final logAnalyzerProvider =
    Provider<LogAnalyzer>((ref) => LogAnalyzer(ref.read(coreProvider)));
final modpackServiceProvider =
    Provider<ModpackService>((ref) => ModpackService(ref.read(coreProvider)));

// ------------------------------------------------------------- l10n
final localeProvider = StateProvider<String>((ref) => 'en');

final stringsProvider =
    Provider<String Function(String)>((ref) {
  final locale = ref.watch(localeProvider);
  return (String key) => NovaStrings.tr(locale, key);
});

// ------------------------------------------------------------- manifest
final manifestProvider = FutureProvider<List<McVersion>>((ref) async {
  final core = ref.read(coreProvider);
  final cacheFile = File(p.join(core.paths.config, 'manifest_cache.json'));
  try {
    final list = await core.piston.getVersionManifest();
    await cacheFile.writeAsString(jsonEncodeSafe(list.map((v) => {
          'id': v.id,
          'type': v.type.name,
          'url': v.url,
          'time': v.time,
          'sha1': v.sha1,
        }).toList()));
    return list;
  } catch (e) {
    if (cacheFile.existsSync()) {
      final cached = jsonList(cacheFile.readAsStringSync());
      return cached.map((m) {
        final j = m as Map<String, dynamic>;
        return McVersion.fromJson({
          'id': j['id'],
          'type': j['type'] == 'release' ? 'release' : (j['type'] == 'snapshot' ? 'snapshot' : 'old_beta'),
          'url': j['url'],
          'time': j['time'],
          'sha1': j['sha1'],
        });
      }).toList();
    }
    rethrow;
  }
});

// ------------------------------------------------------------- installed
class InstalledNotifier extends StateNotifier<List<InstalledVersion>> {
  InstalledNotifier(this.core) : super([]) {
    reload();
  }
  final NovaCore core;

  Future<void> reload() async {
    state = await core.db.installedVersions();
  }
}

final installedProvider =
    StateNotifierProvider<InstalledNotifier, List<InstalledVersion>>(
        (ref) => InstalledNotifier(ref.read(coreProvider)));

final selectedVersionIdProvider = StateProvider<String?>((ref) => null);
final selectedLoaderProvider =
    StateProvider<LoaderType>((ref) => LoaderType.vanilla);

// ------------------------------------------------------------- install
class InstallController extends StateNotifier<InstallState> {
  InstallController(this.core) : super(const InstallState.idle()) {
    core.downloads.progress.listen(_onProgress);
  }

  final NovaCore core;
  final Map<String, DownloadProgress> _perTask = {};

  void _onProgress(DownloadProgress p) {
    if (p.state == DownloadTaskState.failed) {
      state = InstallState.failed(p.error ?? 'download failed');
      return;
    }
    if (p.state == DownloadTaskState.cancelled) {
      _perTask.remove(p.taskId);
      return;
    }
    _perTask[p.taskId] = p;
    int done = 0;
    int total = 0;
    double speed = 0;
    _perTask.forEach((k, v) {
      done += v.doneBytes;
      total += v.totalBytes;
      speed += v.bytesPerSec;
    });
    state = InstallState.downloading(
      doneBytes: done,
      totalBytes: total,
      speed: speed,
      file: p.taskId,
    );
  }

  Future<bool> install(McVersion v, LoaderType loader) async {
    _perTask.clear();
    state = const InstallState.downloading();
    final svc = VersionService(core);
    final ok = await svc.install(v, loader: loader);
    if (ok) {
      state = const InstallState.success();
    } else if (state.kind != InstallKind.failed) {
      state = const InstallState.failed('install failed');
    }
    return ok;
  }
}

class InstallState {
  const InstallState._(this.kind,
      {this.doneBytes = 0, this.totalBytes = 0, this.speed = 0, this.file = '', this.error = ''});

  final InstallKind kind;
  final int doneBytes;
  final int totalBytes;
  final double speed;
  final String file;
  final String error;

  const InstallState.idle() : this._(InstallKind.idle);
  const InstallState.downloading(
      {int doneBytes = 0, int totalBytes = 0, double speed = 0, String file = ''})
      : this._(InstallKind.downloading,
            doneBytes: doneBytes, totalBytes: totalBytes, speed: speed, file: file);
  const InstallState.failed(String error) : this._(InstallKind.failed, error: error);
  const InstallState.success() : this._(InstallKind.success);
}

enum InstallKind { idle, downloading, failed, success }

final installControllerProvider =
    StateNotifierProvider<InstallController, InstallState>(
        (ref) => InstallController(ref.read(coreProvider)));

/// PLAY button real state machine (§6).
final playStateProvider = Provider<PlayState>((ref) {
  final install = ref.watch(installControllerProvider);
  final selected = ref.watch(selectedVersionIdProvider);
  final installed = ref.watch(installedProvider);
  return PlayRules.compute(
    selectedVersion: selected,
    installedIds: installed.map((v) => v.id).toSet(),
    downloading: install.kind == InstallKind.downloading,
  );
});

// ------------------------------------------------------------- profiles
class ProfilesNotifier extends StateNotifier<List<UserProfile>> {
  ProfilesNotifier(this.core) : super([]) {
    reload();
  }
  final NovaCore core;
  Future<void> reload() async {
    state = await core.db.profiles();
  }
}

final profilesProvider =
    StateNotifierProvider<ProfilesNotifier, List<UserProfile>>(
        (ref) => ProfilesNotifier(ref.read(coreProvider)));

// ------------------------------------------------------------- servers
class ServersNotifier extends StateNotifier<List<ServerEntry>> {
  ServersNotifier(this.core) : super([]) {
    reload();
  }
  final NovaCore core;
  Future<void> reload() async {
    state = await core.db.servers();
  }
}

final serversProvider =
    StateNotifierProvider<ServersNotifier, List<ServerEntry>>(
        (ref) => ServersNotifier(ref.read(coreProvider)));

// ------------------------------------------------------------- mods
class ModsNotifier extends StateNotifier<List<ModInfo>> {
  ModsNotifier(this.core) : super([]) {
    reload();
  }
  final NovaCore core;
  Future<void> reload() async {
    state = await core.db.mods();
  }
}

final modsProvider =
    StateNotifierProvider<ModsNotifier, List<ModInfo>>(
        (ref) => ModsNotifier(ref.read(coreProvider)));

/// Content screen tab index (0 mods, 1 maps, 2 resources, 3 modpacks).
final contentTabProvider = StateProvider<int>((ref) => 0);

// ------------------------------------------------------------- device
final deviceSpecsProvider = FutureProvider<DeviceSpecs>((ref) =>
    ref.read(perfServiceProvider).readDeviceSpecs());

final runtimesProvider = FutureProvider<List<RuntimeApp>>((ref) =>
    ref.read(runtimeBridgeProvider).installedRuntimes());
