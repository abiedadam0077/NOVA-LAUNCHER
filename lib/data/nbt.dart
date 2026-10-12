import 'dart:convert';
import 'dart:typed_data';

import '../domain/models.dart';

/// Minimal, exact NBT (Named Binary Tag) implementation used to keep
/// NOVA's server list in sync with Minecraft's own `servers.dat`.
/// Big-endian, modified-UTF8 lengths, uncompressed (vanilla tolerant).

class _W {
  final BytesBuilder b = BytesBuilder();

  void u8(int v) => b.addByte(v & 0xFF);

  void u16(int v) {
    final d = ByteData(2)..setUint16(0, v);
    b.add(d.buffer.asUint8List());
  }

  void i32(int v) {
    final d = ByteData(4)..setInt32(0, v);
    b.add(d.buffer.asUint8List());
  }

  void i64(int v) {
    final d = ByteData(8)..setInt64(0, v);
    b.add(d.buffer.asUint8List());
  }

  void utf(String s) {
    final bytes = utf8.encode(s);
    u16(bytes.length);
    b.add(bytes);
  }
}

class Nbt {
  Nbt._();

  // tag ids
  static const int tEnd = 0;
  static const int tByte = 1;
  static const int tShort = 2;
  static const int tInt = 3;
  static const int tLong = 4;
  static const int tFloat = 5;
  static const int tDouble = 6;
  static const int tString = 8;
  static const int tList = 9;
  static const int tCompound = 10;

  /// Builds servers.dat exactly as Minecraft expects:
  /// root{ servers: [ { name, ip, acceptTextures? } ] }
  static Uint8List writeServersDat(List<ServerEntry> servers) {
    final w = _W();
    w.u8(tCompound);
    w.utf(''); // root name
    w.u8(tList);
    w.utf('servers');
    w.u8(tCompound); // element type
    w.i32(servers.length);
    for (final s in servers) {
      w.u8(tString);
      w.utf('name');
      w.utf(s.name);
      w.u8(tString);
      w.utf('ip');
      w.utf(s.ip);
      w.u8(tByte);
      w.utf('acceptTextures');
      w.u8(1);
      w.u8(tEnd); // end of list element compound
    }
    w.u8(tEnd); // end of root compound
    return w.b.toBytes();
  }

  static List<ServerEntry> readServersDat(Uint8List bytes) {
    final r = _R(bytes);
    final root = r.readRoot();
    if (root is! NbtCompound) return [];
    final list = root.children['servers'];
    if (list is! NbtList) return [];
    final out = <ServerEntry>[];
    int i = 0;
    for (final item in list.items) {
      if (item is NbtCompound) {
        final name = (item.children['name'] as NbtString?)?.value ?? '';
        var ip = (item.children['ip'] as NbtString?)?.value ?? '';
        String address = ip;
        int port = 25565;
        if (ip.contains(':')) {
          final parts = ip.split(':');
          address = parts[0];
          port = int.tryParse(parts[1]) ?? 25565;
        }
        out.add(ServerEntry(id: i, name: name, address: address, port: port, position: i));
        i++;
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------- reader

abstract class NbtValue {
  int get tag;
}

class NbtCompound extends NbtValue {
  NbtCompound(this.children);
  final Map<String, NbtValue> children;
  @override
  int get tag => Nbt.tCompound;
}

class NbtList extends NbtValue {
  NbtList(this.elemType, this.items);
  final int elemType;
  final List<NbtValue> items;
  @override
  int get tag => Nbt.tList;
}

class NbtString extends NbtValue {
  NbtString(this.value);
  final String value;
  @override
  int get tag => Nbt.tString;
}

class NbtNum extends NbtValue {
  NbtNum(this.tag, this.value);
  @override
  final int tag;
  final num value;
}

class NbtEnd extends NbtValue {
  @override
  int get tag => Nbt.tEnd;
}

class _R {
  _R(this.bytes);
  final Uint8List bytes;
  int p = 0;

  int u8() => bytes[p++];

  int u16() {
    final v = ByteData.sublistView(bytes, p, p + 2).getUint16(0);
    p += 2;
    return v;
  }

  int i32() {
    final v = ByteData.sublistView(bytes, p, p + 4).getInt32(0);
    p += 4;
    return v;
  }

  int i64() {
    final v = ByteData.sublistView(bytes, p, p + 8).getInt64(0);
    p += 8;
    return v;
  }

  String utf() {
    final len = u16();
    final s = utf8.decode(bytes.sublist(p, p + len));
    p += len;
    return s;
  }

  NbtValue readRoot() {
    final tag = u8();
    if (tag != Nbt.tCompound) return NbtEnd();
    utf(); // root name
    return _readPayload(Nbt.tCompound);
  }

  NbtValue _readPayload(int tag) {
    switch (tag) {
      case Nbt.tByte:
        final v = u8();
        return NbtNum(tag, v > 127 ? v - 256 : v);
      case Nbt.tShort:
        return NbtNum(tag, u16());
      case Nbt.tInt:
        return NbtNum(tag, i32());
      case Nbt.tLong:
        return NbtNum(tag, i64());
      case Nbt.tFloat:
        final fv = ByteData.sublistView(bytes, p, p + 4).getFloat32(0);
        p += 4;
        return NbtNum(tag, fv);
      case Nbt.tDouble:
        final v = ByteData.sublistView(bytes, p, p + 8).getFloat64(0);
        p += 8;
        return NbtNum(tag, v);
      case Nbt.tString:
        return NbtString(utf());
      case Nbt.tList:
        final elem = u8();
        final count = i32();
        final items = <NbtValue>[];
        for (int i = 0; i < count; i++) {
          items.add(_readPayload(elem));
        }
        return NbtList(elem, items);
      case Nbt.tCompound:
        final children = <String, NbtValue>{};
        while (true) {
          final childTag = u8();
          if (childTag == Nbt.tEnd) break;
          final name = utf();
          children[name] = _readPayload(childTag);
        }
        return NbtCompound(children);
      default:
        throw FormatException('Unsupported NBT tag $tag');
    }
  }
}
