import 'http.dart';
import 'jsonx.dart';

/// Fabric loader metadata (public API, no key required).
class FabricMeta {
  FabricMeta(this.http);
  final NovaHttp http;

  static const String base = 'https://meta.fabricmc.net/v2';

  Future<String?> latestLoader(String mcVersion) async {
    final res = await http.get('$base/versions/loader/$mcVersion');
    if (res.statusCode != 200) return null;
    final list = jsonList(res.body);
    if (list.isEmpty) return null;
    final first = list[0] as Map<String, dynamic>;
    final loader = first['loader'] as Map<String, dynamic>?;
    return loader?['version'] as String?;
  }

  Future<List<String>> loaderVersions() async {
    final res = await http.get('$base/versions/loader');
    if (res.statusCode != 200) return [];
    return jsonList(res.body)
        .map((e) => (e as Map<String, dynamic>)['version'] as String)
        .toList();
  }

  /// Fabric profile version JSON to save as versions/<id>/<id>.json so that
  /// runtimes understand the profile (inheritsFrom base MC version).
  Future<Map<String, dynamic>?> buildProfileJson({
    required String mcVersion,
    required String loaderVersion,
  }) async {
    final res = await http
        .get('$base/versions/loader/$mcVersion/$loaderVersion/profile/json');
    if (res.statusCode != 200) return null;
    return jsonMap(res.body);
  }
}
