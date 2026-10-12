import 'dart:convert';

/// Domain entities. All models are immutable value objects parsed from
/// official sources (Mojang Piston, Fabric Meta, Modrinth) or local storage.

enum ReleaseType { release, snapshot, beta, alpha, unknown }

class McVersion {
  const McVersion({
    required this.id,
    required this.type,
    required this.url,
    required this.time,
    this.sha1,
  });

  final String id;
  final ReleaseType type;
  final String url;
  final String time;
  final String? sha1;

  static McVersion fromJson(Map<String, dynamic> j) => McVersion(
        id: j['id'] as String,
        type: _parseType(j['type'] as String? ?? 'unknown'),
        url: j['url'] as String,
        time: j['time'] as String? ?? '',
        sha1: j['sha1'] as String?,
      );

  static ReleaseType _parseType(String t) {
    switch (t) {
      case 'release':
        return ReleaseType.release;
      case 'snapshot':
        return ReleaseType.snapshot;
      case 'old_beta':
        return ReleaseType.beta;
      case 'old_alpha':
        return ReleaseType.alpha;
      default:
        return ReleaseType.unknown;
    }
  }
}

class DownloadRef {
  const DownloadRef({required this.url, this.sha1, this.size = 0, this.path = ''});
  final String url;
  final String? sha1;
  final int size;
  final String path;

  static DownloadRef? fromJson(Map<String, dynamic>? j) {
    if (j == null || j['url'] == null) return null;
    return DownloadRef(
      url: j['url'] as String,
      sha1: j['sha1'] as String?,
      size: (j['size'] as num?)?.toInt() ?? 0,
      path: (j['path'] as String?) ?? '',
    );
  }
}

class LibraryRef {
  const LibraryRef({required this.name, this.artifact, this.skipReason});
  final String name;
  final DownloadRef? artifact;
  final String? skipReason;

  static LibraryRef fromJson(Map<String, dynamic> j) {
    final downloads = j['downloads'] as Map<String, dynamic>?;
    final rules = j['rules'] as List?;
    String? skip;
    if (rules != null) {
      // Keep it simple and honest: only unconditional "allow" or absent rules.
      final actions = rules.map((r) => (r as Map)['action'] as String?).toList();
      if (actions.contains('disallow')) skip = 'rule-disallow';
    }
    return LibraryRef(
      name: j['name'] as String,
      artifact: DownloadRef.fromJson(downloads?['artifact'] as Map<String, dynamic>?),
      skipReason: skip,
    );
  }
}

class McVersionDetail {
  const McVersionDetail({
    required this.id,
    required this.mainClass,
    required this.client,
    required this.libraries,
    required this.assetsId,
    required this.assetsUrl,
    this.javaMajor = 8,
  });

  final String id;
  final String mainClass;
  final DownloadRef client;
  final List<LibraryRef> libraries;
  final String assetsId;
  final String assetsUrl;
  final int javaMajor;

  static McVersionDetail fromJson(Map<String, dynamic> j) {
    final downloads = j['downloads'] as Map<String, dynamic>;
    final client = DownloadRef.fromJson(downloads['client'] as Map<String, dynamic>);
    final java = j['javaVersion'] as Map<String, dynamic>?;
    return McVersionDetail(
      id: j['id'] as String,
      mainClass: j['mainClass'] as String? ?? '',
      client: client!,
      libraries: (j['libraries'] as List)
          .map((e) => LibraryRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      assetsId: j['assets'] as String? ?? 'legacy',
      assetsUrl: j['assetIndex']?['url'] as String? ?? '',
      javaMajor: (java?['majorVersion'] as num?)?.toInt() ?? 8,
    );
  }
}

class AssetObject {
  const AssetObject({required this.hash, required this.size});
  final String hash;
  final int size;

  static Map<String, AssetObject> parseIndex(String jsonBody) {
    // objects is a map of logical path -> {hash,size}.
    final decoded = jsonDecode(jsonBody) as Map<String, dynamic>;
    final objects = decoded['objects'] as Map<String, dynamic>;
    return objects.map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(
        k,
        AssetObject(hash: m['hash'] as String, size: (m['size'] as num).toInt()),
      );
    });
  }
}

enum LoaderType { vanilla, fabric, forge, neoforge, quilt }

class InstalledVersion {
  const InstalledVersion({
    required this.id,
    this.loader = LoaderType.vanilla,
    this.loaderVersion,
    required this.sizeBytes,
    required this.installedAt,
    this.javaMajor = 8,
  });

  final String id;
  final LoaderType loader;
  final String? loaderVersion;
  final int sizeBytes;
  final DateTime installedAt;
  final int javaMajor;

  Map<String, Object?> toMap() => {
        'id': id,
        'loader': loader.name,
        'loaderVersion': loaderVersion,
        'sizeBytes': sizeBytes,
        'installedAt': installedAt.millisecondsSinceEpoch,
        'javaMajor': javaMajor,
      };

  static InstalledVersion fromMap(Map<String, Object?> m) => InstalledVersion(
        id: m['id'] as String,
        loader: LoaderType.values.firstWhere(
          (e) => e.name == (m['loader'] as String? ?? 'vanilla'),
          orElse: () => LoaderType.vanilla,
        ),
        loaderVersion: m['loaderVersion'] as String?,
        sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
        installedAt:
            DateTime.fromMillisecondsSinceEpoch((m['installedAt'] as num?)?.toInt() ?? 0),
        javaMajor: (m['javaMajor'] as num?)?.toInt() ?? 8,
      );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.type = 'local',
    this.skinPath,
    this.skinModel = 'classic',
    this.isDefault = false,
  });

  final String id;
  final String name;

  /// 'local' | 'microsoft'
  final String type;
  final String? skinPath;
  final String skinModel;
  final bool isDefault;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'skinPath': skinPath,
        'skinModel': skinModel,
        'isDefault': isDefault ? 1 : 0,
      };

  static UserProfile fromMap(Map<String, Object?> m) => UserProfile(
        id: m['id'] as String,
        name: m['name'] as String,
        type: m['type'] as String? ?? 'local',
        skinPath: m['skinPath'] as String?,
        skinModel: m['skinModel'] as String? ?? 'classic',
        isDefault: (m['isDefault'] as int? ?? 0) == 1,
      );

  UserProfile copyWith({String? name, String? skinPath, String? skinModel, bool? isDefault}) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        type: type,
        skinPath: skinPath ?? this.skinPath,
        skinModel: skinModel ?? this.skinModel,
        isDefault: isDefault ?? this.isDefault,
      );
}

class ServerEntry {
  const ServerEntry({
    required this.id,
    required this.name,
    required this.address,
    this.port = 25565,
    this.description = '',
    this.position = 0,
  });

  final int? id;
  final String name;
  final String address;
  final int port;
  final String description;
  final int position;

  /// "host:port" as Minecraft expects (port omitted when default).
  String get ip => port == 25565 ? address : '$address:$port';

  ServerEntry copyWith({String? name, String? address, int? port, String? description, int? position}) =>
      ServerEntry(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        port: port ?? this.port,
        description: description ?? this.description,
        position: position ?? this.position,
      );
}

class ServerStatus {
  const ServerStatus({required this.online, this.motd, this.playersOnline, this.maxPlayers, this.versionName, this.latencyMs});
  final bool online;
  final String? motd;
  final int? playersOnline;
  final int? maxPlayers;
  final String? versionName;
  final int? latencyMs;
}

class DeviceSpecs {
  const DeviceSpecs({
    this.cpuName = '',
    this.abis = const [],
    this.totalRamBytes = 0,
    this.availableRamBytes = 0,
    this.androidVersion = '',
    this.sdkInt = 0,
    this.screenWidthPx = 0,
    this.screenHeightPx = 0,
    this.screenDensity = 1,
    this.internalStorageFreeBytes = 0,
    this.internalStorageTotalBytes = 0,
    this.gpuRenderer,
    this.gpuVendor,
    this.deviceModel = '',
  });

  final String cpuName;
  final List<String> abis;
  final int totalRamBytes;
  final int availableRamBytes;
  final String androidVersion;
  final int sdkInt;
  final int screenWidthPx;
  final int screenHeightPx;
  final double screenDensity;
  final int internalStorageFreeBytes;
  final int internalStorageTotalBytes;
  final String? gpuRenderer;
  final String? gpuVendor;
  final String deviceModel;

  static const DeviceSpecs unknown = DeviceSpecs();

  static DeviceSpecs fromMap(Map m) => DeviceSpecs(
        cpuName: (m['cpuName'] as String?) ?? '',
        abis: (m['abis'] as List? ?? []).map((e) => e.toString()).toList(),
        totalRamBytes: (m['totalRamBytes'] as num?)?.toInt() ?? 0,
        availableRamBytes: (m['availableRamBytes'] as num?)?.toInt() ?? 0,
        androidVersion: (m['androidVersion'] as String?) ?? '',
        sdkInt: (m['sdkInt'] as num?)?.toInt() ?? 0,
        screenWidthPx: (m['screenWidthPx'] as num?)?.toInt() ?? 0,
        screenHeightPx: (m['screenHeightPx'] as num?)?.toInt() ?? 0,
        screenDensity: (m['screenDensity'] as num?)?.toDouble() ?? 1,
        internalStorageFreeBytes: (m['internalStorageFreeBytes'] as num?)?.toInt() ?? 0,
        internalStorageTotalBytes: (m['internalStorageTotalBytes'] as num?)?.toInt() ?? 0,
        gpuRenderer: m['gpuRenderer'] as String?,
        gpuVendor: m['gpuVendor'] as String?,
        deviceModel: (m['deviceModel'] as String?) ?? '',
      );

  int get totalRamMb => totalRamBytes ~/ (1024 * 1024);
}

enum PerfProfileId { lite, balanced, performance, visual, custom }

class PerfPreset {
  const PerfPreset({
    required this.id,
    required this.renderDistance,
    required this.simulationDistance,
    required this.graphicsFancy,
    required this.particles, // 0 all, 1 decreased, 2 minimal
    required this.vsync,
    required this.maxFps,
    required this.ao, // 0..2
    required this.ramMb,
  });

  final PerfProfileId id;
  final int renderDistance;
  final int simulationDistance;
  final bool graphicsFancy;
  final int particles;
  final bool vsync;
  final int maxFps;
  final int ao;
  final int ramMb;

  /// Honest, device-derived options (never exceeds safe RAM fraction).
  static PerfPreset forDevice(DeviceSpecs s, PerfProfileId id) {
    final ram = s.totalRamMb <= 0 ? 2048 : s.totalRamMb;
    switch (id) {
      case PerfProfileId.lite:
        return PerfPreset(
          id: id,
          renderDistance: 4,
          simulationDistance: 5,
          graphicsFancy: false,
          particles: 2,
          vsync: false,
          maxFps: 60,
          ao: 0,
          ramMb: _safeRam(ram, 0.25, 512, 1024),
        );
      case PerfProfileId.balanced:
        return PerfPreset(
          id: id,
          renderDistance: 8,
          simulationDistance: 8,
          graphicsFancy: true,
          particles: 1,
          vsync: false,
          maxFps: 90,
          ao: 1,
          ramMb: _safeRam(ram, 0.35, 1024, 2048),
        );
      case PerfProfileId.performance:
        return PerfPreset(
          id: id,
          renderDistance: 10,
          simulationDistance: 10,
          graphicsFancy: true,
          particles: 1,
          vsync: false,
          maxFps: 120,
          ao: 2,
          ramMb: _safeRam(ram, 0.45, 1536, 3072),
        );
      case PerfProfileId.visual:
        return PerfPreset(
          id: id,
          renderDistance: 16,
          simulationDistance: 12,
          graphicsFancy: true,
          particles: 0,
          vsync: true,
          maxFps: 260,
          ao: 2,
          ramMb: _safeRam(ram, 0.5, 2048, 4096),
        );
      case PerfProfileId.custom:
        return PerfPreset(
          id: id,
          renderDistance: 12,
          simulationDistance: 10,
          graphicsFancy: true,
          particles: 1,
          vsync: false,
          maxFps: 120,
          ao: 2,
          ramMb: _safeRam(ram, 0.4, 1024, 3072),
        );
    }
  }

  static int _safeRam(int totalMb, double fraction, int min, int max) {
    // Never more than half of the device RAM (Android needs the rest).
    final half = totalMb ~/ 2;
    final v = (totalMb * fraction).toInt().clamp(min, max);
    return v > half ? half : v;
  }

  /// options.txt lines written to the game directory.
  Map<String, String> toOptions() => {
        'renderDistance': '$renderDistance',
        'simulationDistance': '$simulationDistance',
        'graphics': graphicsFancy ? 'true' : 'false',
        'particles': '$particles',
        'enableVsync': vsync ? 'true' : 'false',
        'maxFps': '$maxFps',
        'ao': '$ao',
        'fboEnable': 'true',
        'renderClouds': graphicsFancy ? 'true' : 'false',
        'entityShadows': graphicsFancy ? 'true' : 'false',
      };
}

class RuntimeApp {
  const RuntimeApp({required this.packageName, required this.name, this.version = ''});
  final String packageName;
  final String name;
  final String version;
}

enum PlayState { notInstalled, needsDownload, ready, preparing, running }

/// Pure state machine for the PLAY button (§6) — unit-tested.
class PlayRules {
  static PlayState compute({
    required String? selectedVersion,
    required Set<String> installedIds,
    required bool downloading,
  }) {
    if (downloading) return PlayState.preparing;
    if (selectedVersion == null) return PlayState.notInstalled;
    if (!installedIds.contains(selectedVersion)) {
      return PlayState.notInstalled;
    }
    return PlayState.ready;
  }
}

class DownloadProgress {
  const DownloadProgress({
    required this.taskId,
    required this.doneBytes,
    required this.totalBytes,
    required this.bytesPerSec,
    required this.state,
    this.error,
  });
  final String taskId;
  final int doneBytes;
  final int totalBytes;
  final double bytesPerSec;
  final DownloadTaskState state;
  final String? error;
}

enum DownloadTaskState { queued, running, paused, done, failed, cancelled }

class LogIssue {
  const LogIssue({required this.summary, required this.cause, required this.suggestions, this.raw});
  final String summary;
  final String cause;
  final List<String> suggestions;
  final String? raw;
}

class ModInfo {
  const ModInfo({
    required this.id,
    required this.fileName,
    required this.path,
    required this.enabled,
    this.slug,
    this.title,
    this.modVersion,
    this.loader,
    this.mcVersion,
    this.category,
    this.sourceUrl,
    this.license,
  });

  final int? id;
  final String fileName;
  final String path;
  final bool enabled;
  final String? slug;
  final String? title;
  final String? modVersion;
  final String? loader;
  final String? mcVersion;
  final String? category;
  final String? sourceUrl;
  final String? license;

  ModInfo copyWith({bool? enabled}) => ModInfo(
        id: id,
        fileName: fileName,
        path: path,
        enabled: enabled ?? this.enabled,
        slug: slug,
        title: title,
        modVersion: modVersion,
        loader: loader,
        mcVersion: mcVersion,
        category: category,
        sourceUrl: sourceUrl,
        license: license,
      );
}

class CatalogProject {
  const CatalogProject({
    required this.slug,
    required this.title,
    required this.projectUrl,
    this.description = '',
    this.iconUrl,
    this.downloads = 0,
    this.categories = const [],
    this.license,
    this.projectType = 'mod',
  });

  final String slug;
  final String title;
  final String projectUrl;
  final String description;
  final String? iconUrl;
  final int downloads;
  final List<String> categories;
  final String? license;

  /// 'mod' | 'shader' | 'resourcepack' | 'modpack'
  final String projectType;
}

class CatalogVersionFile {
  const CatalogVersionFile({required this.url, required this.fileName, this.size = 0, this.primary = false});
  final String url;
  final String fileName;
  final int size;
  final bool primary;
}

class CatalogVersion {
  const CatalogVersion({
    required this.id,
    required this.name,
    this.mcVersions = const [],
    this.loaders = const [],
    this.files = const [],
    this.datePublished = '',
  });
  final String id;
  final String name;
  final List<String> mcVersions;
  final List<String> loaders;
  final List<CatalogVersionFile> files;
  final String datePublished;
}

class WorldInfo {
  const WorldInfo({
    required this.name,
    required this.path,
    this.sizeBytes = 0,
    this.lastPlayed,
    this.category = 'Survival',
  });
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime? lastPlayed;
  final String category;
}

class PackInfo {
  const PackInfo({
    required this.name,
    required this.path,
    required this.kind, // 'resourcepack' | 'shaderpack'
    this.sizeBytes = 0,
    this.enabled = false,
    this.previewPath,
    this.mcMetaVersion,
  });
  final String name;
  final String path;
  final String kind;
  final int sizeBytes;
  final bool enabled;
  final String? previewPath;
  final int? mcMetaVersion;
}
