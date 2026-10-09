import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/colors.dart';
import '../core/utils.dart';
import '../domain/providers.dart';
import 'widgets/core_widgets.dart';

/// Real file manager over the game directory (inside Settings, per spec).
class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  List<String> _stack = const [];
  String _query = '';

  Directory get _current {
    final core = ref.read(coreProvider);
    return Directory(p.joinAll([core.paths.root.path, ..._stack]));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final entries = _listEntries();
    return Scaffold(
      backgroundColor: NovaColors.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('settings.fileManager'), style: const TextStyle(fontSize: 16)),
            Text('/${_stack.join('/')}',
                style: const TextStyle(
                    fontSize: 10, color: NovaColors.textSecondary)),
          ],
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: NovaColors.textPrimary),
              decoration: InputDecoration(
                hintText: t('common.search'),
                hintStyle: const TextStyle(color: NovaColors.textSecondary),
                filled: true,
                fillColor: NovaColors.surface.withOpacity(0.7),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entries.isEmpty
                ? NovaEmpty(message: t('common.empty'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      final isDir = e is Directory;
                      return NovaGlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        onTap: isDir
                            ? () => setState(
                                () => _stack = [..._stack, p.basename(e.path)])
                            : null,
                        child: Row(
                          children: [
                            Icon(
                              isDir
                                  ? Icons.folder_outlined
                                  : Icons.description_outlined,
                              color: isDir
                                  ? NovaColors.electricBlue
                                  : NovaColors.textSecondary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.basename(e.path),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13)),
                                  Text(
                                    isDir
                                        ? ''
                                        : NovaUtils.formatBytes(
                                            (e as File).lengthSync()),
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: NovaColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: NovaColors.danger),
                              onPressed: () => _confirmDelete(e),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<FileSystemEntity> _listEntries() {
    final dir = _current;
    if (!dir.existsSync()) return [];
    final all = dir.listSync()
      ..sort((a, b) {
        if (a is Directory && b is! Directory) return -1;
        if (a is! Directory && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });
    if (_query.isEmpty) return all;
    return all
        .where((e) =>
            p.basename(e.path).toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  Future<void> _confirmDelete(FileSystemEntity e) async {
    final t = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('common.delete')),
        content: Text(p.basename(e.path)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('common.confirm'))),
        ],
      ),
    );
    if (ok != true) return;
    if (e is Directory) {
      await e.delete(recursive: true);
    } else {
      await e.delete();
    }
    setState(() {});
  }
}
