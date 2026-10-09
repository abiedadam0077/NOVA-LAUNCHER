/// Formatting + comparison helpers used across NOVA.
class NovaUtils {
  NovaUtils._();

  static String formatBytes(num bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double v = bytes.toDouble();
    int i = -1;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
  }

  static String formatSpeed(double bytesPerSec) =>
      '${formatBytes(bytesPerSec)}/s';

  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  /// Minecraft-style version comparison: numeric parts, then remainder.
  /// 1.20.1 > 1.20 ; 1.9 > 1.10 is false ; snapshots/ids compare lexicographic-safe.
  static int compareVersions(String a, String b) {
    final pa = _split(a);
    final pb = _split(b);
    final n = pa.length < pb.length ? pa.length : pb.length;
    for (int i = 0; i < n; i++) {
      final x = pa[i];
      final y = pb[i];
      if (x.isNumeric && y.isNumeric) {
        final c = int.parse(x.text).compareTo(int.parse(y.text));
        if (c != 0) return c;
      } else {
        final c = x.text.compareTo(y.text);
        if (c != 0) return c;
      }
    }
    return pa.length.compareTo(pb.length);
  }

  static List<_VPart> _split(String v) {
    final parts = <_VPart>[];
    final buf = StringBuffer();
    bool? numeric;
    for (final ch in v.split('')) {
      final isNum = RegExp(r'[0-9]').hasMatch(ch);
      if (numeric == null) numeric = isNum;
      if (isNum != numeric) {
        if (buf.isNotEmpty) parts.add(_VPart(buf.toString(), numeric));
        buf.clear();
        numeric = isNum;
      }
      buf.write(ch);
    }
    if (buf.isNotEmpty) parts.add(_VPart(buf.toString(), numeric!));
    return parts;
  }

  static String firstNonNull(String? a, String? b, String fallback) =>
      a ?? b ?? fallback;
}

class _VPart {
  const _VPart(this.text, this.isNumeric);
  final String text;
  final bool isNumeric;
}
