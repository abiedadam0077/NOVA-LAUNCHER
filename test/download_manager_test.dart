import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_launcher/data/download_manager.dart';
import 'package:nova_launcher/data/http.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nova_dl_test');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  http.Client _clientReturning(List<int> bytes, {int status = 200}) {
    return MockClient.streaming((req, body) async {
      return http.StreamedResponse(
        Stream.fromIterable([bytes]),
        status,
        contentLength: bytes.length,
      );
    });
  }

  test('downloads file and verifies sha1', () async {
    final payload = utf8.encode('nova launcher payload');
    final sha = sha1.convert(payload).toString();
    final mgr = DownloadManager(http: NovaHttp(client: _clientReturning(payload)));

    final dest = '${tmp.path}/out.bin';
    final results = await mgr.runAll([
      DownloadTask(
          id: 'a', url: 'https://example.invalid/a', destPath: dest, sha1: sha),
    ]);
    expect(results['a'], true);
    expect(File(dest).readAsBytesSync(), payload);
  });

  test('sha1 mismatch fails honestly', () async {
    final payload = utf8.encode('some bytes');
    final mgr = DownloadManager(http: NovaHttp(client: _clientReturning(payload)));
    final dest = '${tmp.path}/bad.bin';
    final results = await mgr.runAll([
      DownloadTask(
          id: 'a',
          url: 'https://example.invalid/a',
          destPath: dest,
          sha1: '0' * 40),
    ]);
    expect(results['a'], false);
    expect(File(dest).existsSync(), false);
  });

  test('http 500 retries then fails', () async {
    int hits = 0;
    final client = MockClient.streaming((req, body) async {
      hits++;
      return http.StreamedResponse(const Stream.empty(), 500);
    });
    final mgr = DownloadManager(http: NovaHttp(client: client));
    final results = await mgr.runAll([
      DownloadTask(
          id: 'a', url: 'https://example.invalid/x', destPath: '${tmp.path}/x'),
    ]);
    expect(results['a'], false);
    expect(hits, 3);
  });

  test('resume sends Range header', () async {
    final full = utf8.encode('0123456789');
    String? seenRange;
    final client = MockClient.streaming((req, body) async {
      seenRange = req.headers['Range'];
      final from = seenRange == null ? 0 : int.parse(seenRange!.split('=')[1].split('-')[0]);
      return http.StreamedResponse(
        Stream.fromIterable([full.sublist(from)]),
        seenRange == null ? 200 : 206,
        contentLength: full.length - from,
      );
    });
    final dest = '${tmp.path}/resume.bin';
    File(dest).writeAsBytesSync(full.sublist(0, 4));
    final mgr = DownloadManager(http: NovaHttp(client: client));
    final results = await mgr.runAll([
      DownloadTask(
          id: 'a',
          url: 'https://example.invalid/r',
          destPath: dest,
          expectedSize: full.length),
    ]);
    expect(results['a'], true);
    expect(seenRange, 'bytes=4-');
    expect(File(dest).readAsBytesSync(), full);
  });
}
