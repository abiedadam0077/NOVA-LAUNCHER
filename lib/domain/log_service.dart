import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/core.dart';
import '../domain/models.dart';

/// Real crash/game log analysis with conservative, explainable heuristics.
class LogAnalyzer {
  LogAnalyzer(this.core);
  final NovaCore core;

  static const List<String> _patterns = [];

  /// Scans raw game/crash text. Only reports what the patterns can justify.
  List<LogIssue> analyze(String raw) {
    final issues = <LogIssue>[];

    void check(RegExp re, String summary, String cause, List<String> fixes) {
      final m = re.firstMatch(raw);
      if (m != null) {
        issues.add(LogIssue(
          summary: summary,
          cause: cause,
          suggestions: fixes,
          raw: m.group(0),
        ));
      }
    }

    check(
      RegExp(r'java\.lang\.OutOfMemoryError'),
      'Java ran out of memory',
      'The JVM heap is too small for the loaded content (mods/render distance).',
      [
        'Raise RAM allocation in game settings (within device limits).',
        'Apply the LITE or BALANCED performance preset.',
        'Remove memory-heavy mods.',
      ],
    );
    check(
      RegExp(r'ClassNotFoundException|NoClassDefFoundError'),
      'A required class/library is missing',
      'A mod or loader dependency is absent or mismatched.',
      [
        'Check missing dependencies in the Mods manager.',
        'Verify the version files (re-download if corrupted).',
      ],
    );
    check(
      RegExp(r'GLFW|EGL|Failed to create GL context', caseSensitive: false),
      'Graphics initialization failed',
      'The renderer could not create an OpenGL context on this device.',
      [
        'Try another renderer in the runtime settings (ANGLE/VirGL/gl4es).',
        'Use an older Minecraft version with lighter GL requirements.',
      ],
    );
    check(
      RegExp(r'ModResolutionException|Incompatible mods set|DuplicateModsException',
          caseSensitive: false),
      'Mod loader reported a conflict',
      'Two or more mods conflict or a required mod version is wrong.',
      [
        'Review the compatibility notes in the Mods manager.',
        'Remove duplicate mods.',
      ],
    );
    check(
      RegExp(r'Failed to locate|Unable to locate|Missing (file|asset)',
          caseSensitive: false),
      'Missing game files',
      'Some client/libraries/assets files are absent.',
      ['Use "Verify files" on the installed version to re-download missing parts.'],
    );
    return issues;
  }

  Future<String> export(String content, {String name = 'nova_log'}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final f = File(p.join(core.paths.logs, '${name}_$ts.txt'));
    await f.writeAsString(content);
    return f.path;
  }

  Future<List<File>> recentLogs() async {
    final dir = Directory(core.paths.logs);
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
  }
}
