import 'dart:typed_data';

import 'package:archive/archive.dart';

/// archive 3.x exposes entry content dynamically; normalize safely.
extension ArchiveFileX on ArchiveFile {
  Uint8List bytes() {
    final c = content;
    if (c is Uint8List) return c;
    return Uint8List.fromList(c as List<int>);
  }
}
