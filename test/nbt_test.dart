import 'package:flutter_test/flutter_test.dart';
import 'package:nova_launcher/data/nbt.dart';
import 'package:nova_launcher/domain/models.dart';

void main() {
  test('servers.dat roundtrip keeps names, addresses and ports', () {
    final servers = [
      const ServerEntry(
          id: 1, name: 'HypeCraft', address: 'play.hype.dev', port: 25565),
      const ServerEntry(
          id: 2, name: 'Local', address: '192.168.1.10', port: 25577),
    ];
    final bytes = Nbt.writeServersDat(servers);

    // Root must be a compound tag.
    expect(bytes[0], Nbt.tCompound);

    final read = Nbt.readServersDat(bytes);
    expect(read.length, 2);
    expect(read[0].name, 'HypeCraft');
    expect(read[0].address, 'play.hype.dev');
    expect(read[0].port, 25565);
    expect(read[1].address, '192.168.1.10');
    expect(read[1].port, 25577);
  });

  test('default port is omitted in ip string like vanilla', () {
    const s = ServerEntry(id: 1, name: 'A', address: 'mc.example.com');
    expect(s.ip, 'mc.example.com');
    const s2 = ServerEntry(id: 1, name: 'A', address: 'mc.example.com', port: 1234);
    expect(s2.ip, 'mc.example.com:1234');
  });
}
