import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/models.dart';

/// Minecraft Server List Ping (SLP) implemented over a raw socket,
/// following the protocol wiki (handshake + status + ping).
class ServerPing {
  ServerPing._();

  static const int protocolVersion = 766; // 1.20.1; informational only

  static Future<ServerStatus> ping(String host, int port,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      final out = BytesBuilder();

      // Handshake packet
      final handshake = BytesBuilder();
      _writeVarInt(handshake, 0x00); // packet id
      _writeVarInt(handshake, protocolVersion);
      _writeString(handshake, host);
      _writeU16(handshake, port);
      _writeVarInt(handshake, 1); // next state: status
      final hs = handshake.toBytes();
      out.addByte(_varIntSize(hs.length));
      _writeVarInt(out, hs.length);
      out.add(hs);

      // Status request packet (empty)
      out.addByte(1);
      out.addByte(0x00);

      socket.add(out.toBytes());

      final reader = _PacketReader(socket);
      final statusBytes = await reader.nextPacket().timeout(timeout);
      sw.stop();

      // statusBytes: [0x00][json string]
      if (statusBytes.isEmpty || statusBytes[0] != 0x00) {
        return const ServerStatus(online: false);
      }
      final jsonStr = utf8.decode(statusBytes.sublist(1));
      final j = jsonDecode(jsonStr) as Map<String, dynamic>;

      String? motd;
      final desc = j['description'];
      if (desc is String) {
        motd = desc;
      } else if (desc is Map) {
        motd = _flattenDesc(desc);
      }
      final players = j['players'] as Map<String, dynamic>?;
      final version = j['version'] as Map<String, dynamic>?;

      return ServerStatus(
        online: true,
        motd: motd,
        playersOnline: (players?['online'] as num?)?.toInt(),
        maxPlayers: (players?['max'] as num?)?.toInt(),
        versionName: version?['name'] as String?,
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (_) {
      return const ServerStatus(online: false);
    } finally {
      await socket?.close();
      socket?.destroy();
    }
  }

  static String _flattenDesc(Map desc) {
    final sb = StringBuffer();
    void walk(dynamic node) {
      if (node is Map) {
        if (node['text'] is String) sb.write(node['text']);
        if (node['extra'] is List) {
          for (final e in node['extra'] as List) {
            walk(e);
          }
        }
      } else if (node is String) {
        sb.write(node);
      }
    }

    walk(desc);
    return sb.toString().trim();
  }

  static void _writeVarInt(BytesBuilder b, int value) {
    var v = value & 0xFFFFFFFF;
    while (true) {
      var byte = v & 0x7F;
      v = v >> 7;
      if (v != 0) byte |= 0x80;
      b.addByte(byte);
      if (v == 0) break;
    }
  }

  static int _varIntSize(int value) {
    int size = 0;
    var v = value;
    while (true) {
      size++;
      v = v >> 7;
      if (v == 0) break;
    }
    return size;
  }

  static void _writeString(BytesBuilder b, String s) {
    final bytes = utf8.encode(s);
    _writeVarInt(b, bytes.length);
    b.add(bytes);
  }

  static void _writeU16(BytesBuilder b, int v) {
    final d = ByteData(2)..setUint16(0, v);
    b.add(d.buffer.asUint8List());
  }
}

class _PacketReader {
  _PacketReader(this.socket);
  final Socket socket;
  final BytesBuilder _buf = BytesBuilder();
  final StreamController<Uint8List> _packets = StreamController();
  StreamSubscription<Uint8List>? _sub;

  Future<Uint8List> nextPacket() {
    _sub ??= socket.listen((data) {
      _buf.add(data);
      _drain();
    }, onError: (e) {
      if (!_packets.isClosed) _packets.addError(e);
    }, onDone: () {
      if (!_packets.isClosed) _packets.close();
    });
    return _packets.stream.first;
  }

  void _drain() {
    final bytes = _buf.toBytes();
    int offset = 0;
    while (offset < bytes.length) {
      final res = _readVarInt(bytes, offset);
      if (res == null) break;
      final (len, consumed) = res;
      if (bytes.length - offset - consumed < len) break;
      final payload =
          Uint8List.fromList(bytes.sublist(offset + consumed, offset + consumed + len));
      offset += consumed + len;
      _packets.add(payload);
    }
    // compact remaining
    final remaining = bytes.sublist(offset);
    _buf.clear();
    _buf.add(remaining);
  }

  (int, int)? _readVarInt(Uint8List bytes, int start) {
    int result = 0;
    int shift = 0;
    int i = start;
    while (i < bytes.length) {
      final b = bytes[i];
      result |= (b & 0x7F) << shift;
      i++;
      if ((b & 0x80) == 0) return (result, i - start);
      shift += 7;
      if (shift >= 35) return null;
    }
    return null;
  }
}
