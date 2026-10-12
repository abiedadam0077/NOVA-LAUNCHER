import '../domain/models.dart';
import 'http.dart';
import 'jsonx.dart';

/// Modrinth public API — trusted external catalog for mods, shaders,
/// resource packs and modpacks. Downloads are always user-consented.
class ModrinthApi {
  ModrinthApi(this.http);
  final NovaHttp http;

  static const String base = 'https://api.modrinth.com/v2';

  Future<List<CatalogProject>> search({
    required String query,
    required String projectType, // mod | shader | resourcepack | modpack
    String? gameVersion,
    String? loader,
    int limit = 25,
    int offset = 0,
  }) async {
    final facets = <List<String>>[
      ['project_type:$projectType'],
    ];
    if (gameVersion != null) facets.add(['versions:$gameVersion']);
    if (loader != null) facets.add(['categories:$loader']);
    final facetsEncoded = Uri.encodeComponent(
      facets.map((f) => '["${f.join('","')}"]').join(','),
    );
    final url = '$base/search?query=${Uri.encodeComponent(query)}'
        '&facets=$facetsEncoded&limit=$limit&offset=$offset';
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final hits = jsonMap(res.body)['hits'] as List? ?? [];
    return hits.map((e) {
      final m = e as Map<String, dynamic>;
      return CatalogProject(
        slug: m['slug'] as String? ?? '',
        title: m['title'] as String? ?? '',
        projectUrl: 'https://modrinth.com/$projectType/${m['slug']}',
        description: m['description'] as String? ?? '',
        iconUrl: m['icon_url'] as String?,
        downloads: (m['downloads'] as num?)?.toInt() ?? 0,
        categories: (m['categories'] as List? ?? [])
            .map((c) => c.toString())
            .toList(),
        projectType: projectType,
      );
    }).toList();
  }

  Future<Map<String, dynamic>?> project(String slug) async {
    final res = await http.get('$base/project/$slug');
    if (res.statusCode != 200) return null;
    return jsonMap(res.body);
  }

  Future<List<CatalogVersion>> versions(
    String slug, {
    String? gameVersion,
    String? loader,
  }) async {
    var url = '$base/project/$slug/version';
    final params = <String>[];
    if (gameVersion != null) {
      params.add('game_versions=${Uri.encodeComponent(jsonEncodeSafe([gameVersion]))}');
    }
    if (loader != null) {
      params.add('loaders=${Uri.encodeComponent(jsonEncodeSafe([loader]))}');
    }
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    return jsonList(res.body).map((e) {
      final m = e as Map<String, dynamic>;
      final files = (m['files'] as List? ?? []).map((f) {
        final fm = f as Map<String, dynamic>;
        return CatalogVersionFile(
          url: fm['url'] as String,
          fileName: fm['filename'] as String? ?? 'file.jar',
          size: (fm['size'] as num?)?.toInt() ?? 0,
          primary: fm['primary'] as bool? ?? false,
        );
      }).toList();
      files.sort((a, b) => (b.primary ? 1 : 0).compareTo(a.primary ? 1 : 0));
      return CatalogVersion(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        mcVersions: (m['game_versions'] as List? ?? [])
            .map((c) => c.toString())
            .toList(),
        loaders: (m['loaders'] as List? ?? []).map((c) => c.toString()).toList(),
        files: files,
        datePublished: m['date_published'] as String? ?? '',
      );
    }).toList();
  }
}
