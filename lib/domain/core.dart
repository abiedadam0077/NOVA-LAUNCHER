import '../core/motion.dart';
import '../data/download_manager.dart';
import '../data/fabric_meta.dart';
import '../data/http.dart';
import '../data/microsoft_auth.dart';
import '../data/modrinth_api.dart';
import '../data/paths.dart';
import '../data/piston_api.dart';
import '../data/prefs.dart';
import '../data/db.dart';

/// App-wide singletons wired once at startup.
class NovaCore {
  NovaCore._();
  static final NovaCore instance = NovaCore._();

  final NovaHttp http = NovaHttp();
  final NovaPaths paths = NovaPaths();
  final NovaDb db = NovaDb();
  final NovaPrefs prefs = NovaPrefs();
  final LogBuffer logs = LogBuffer();

  late final DownloadManager downloads = DownloadManager(http: http);
  late final PistonApi piston = PistonApi(http);
  late final FabricMeta fabric = FabricMeta(http);
  late final ModrinthApi modrinth = ModrinthApi(http);
  late final MicrosoftAuth msAuth = MicrosoftAuth(http);

  bool ready = false;

  Future<void> init() async {
    if (ready) return;
    await prefs.init();
    await paths.init();
    NovaMotion.reduced = prefs.reducedMotion;
    ready = true;
  }
}

/// In-memory rolling log with export support (no fake entries ever).
class LogBuffer {
  final List<LogLine> lines = [];

  void add(String source, String message, {String level = 'INFO'}) {
    lines.add(LogLine(DateTime.now(), source, message, level));
    if (lines.length > 2000) lines.removeRange(0, lines.length - 2000);
  }

  String render() => lines
      .map((l) =>
          '${l.time.toIso8601String()} [${l.level}] ${l.source}: ${l.message}')
      .join('\n');
}

class LogLine {
  const LogLine(this.time, this.source, this.message, this.level);
  final DateTime time;
  final String source;
  final String message;
  final String level;
}
