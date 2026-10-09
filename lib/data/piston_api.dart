import '../domain/models.dart';
import 'http.dart';
import 'jsonx.dart';

/// Official Mojang Piston endpoints — the same sources the official
/// launcher uses. No redistribution: the user's own client downloads them.
class PistonApi {
  PistonApi(this.http);

  static const String manifestUrl =
      'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json';
  static const String assetBase = 'https://resources.download.minecraft.net';

  final NovaHttp http;

  Future<List<McVersion>> getVersionManifest() async {
    final res = await http.get(manifestUrl);
    if (res.statusCode != 200) {
      throw PistonException('Manifest HTTP ${res.statusCode}');
    }
    final body = jsonMap(res.body);
    final list = body['versions'] as List;
    return list.map((e) => McVersion.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<McVersionDetail> getVersionDetail(String url) async {
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw PistonException('Version json HTTP ${res.statusCode}');
    }
    return McVersionDetail.fromJson(jsonMap(res.body));
  }

  Future<Map<String, AssetObject>> getAssetIndex(String url) async {
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw PistonException('Asset index HTTP ${res.statusCode}');
    }
    return AssetObject.parseIndex(res.body);
  }

  String assetObjectUrl(String hash) =>
      '$assetBase/${hash.substring(0, 2)}/$hash';
}

class PistonException implements Exception {
  PistonException(this.message);
  final String message;
  @override
  String toString() => 'PistonException: $message';
}
