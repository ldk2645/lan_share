import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/device.dart';
import 'log_service.dart';

class DiscoveryService {
  static const int discoveryPort = 40401;
  static const int textPort = 40402;
  static const int filePort = 40403;

  final String selfId;
  final String selfName;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final Map<String, Device> _devices = {};

  final StreamController<List<Device>> _devicesController =
      StreamController<List<Device>>.broadcast();

  Stream<List<Device>> get devicesStream => _devicesController.stream;

  DiscoveryService({required this.selfId, required this.selfName});

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );

    _socket!.broadcastEnabled = true;
    _socket!.listen(_handleSocketEvent);

    await LogService.instance.info(
      'Discovery service started on port $discoveryPort, self=$selfName',
    );

    _broadcastPresence();

    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _broadcastPresence(),
    );

    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _cleanupOfflineDevices(),
    );
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket?.receive();
    if (datagram == null) return;

    _readPresencePacket(datagram);
  }

  Future<void> _readPresencePacket(Datagram datagram) async {
    try {
      final text = utf8.decode(datagram.data);
      final map = jsonDecode(text);

      if (map is! Map<String, dynamic>) return;
      if (map['type'] != 'presence') return;

      final deviceId = map['id'] as String? ?? '';
      if (deviceId.isEmpty || deviceId == selfId) return;

      final name = map['name'] as String? ?? 'Unknown Device';
      final ip = datagram.address.address;
      final remoteTextPort = map['textPort'] as int? ?? textPort;
      final remoteFilePort = map['filePort'] as int? ?? filePort;

      final old = _devices[deviceId];
      final isNewDevice = old == null;

      _devices[deviceId] = Device(
        id: deviceId,
        name: name,
        ip: ip,
        textPort: remoteTextPort,
        filePort: remoteFilePort,
        isManual: old?.isManual ?? false,
        selected: old?.selected ?? false,
        online: true,
        lastSeen: DateTime.now(),
      );

      if (isNewDevice) {
        await LogService.instance.info(
          'Discovered device: $name ($ip, text=$remoteTextPort, file=$remoteFilePort)',
        );
      }

      _emitDevices();

      final needReply = map['reply'] != true;
      if (needReply) {
        await _sendPresenceTo(datagram.address, reply: true);
      }
    } catch (e) {
      await LogService.instance.warn('Bad discovery packet ignored: $e');
    }
  }

  Future<void> _broadcastPresence() async {
    final localIp = await _findLocalIpv4();
    if (localIp == null) {
      await LogService.instance.warn('Local IPv4 not found');
      return;
    }

    final packet = {
      'type': 'presence',
      'id': selfId,
      'name': selfName,
      'ip': localIp,
      'textPort': textPort,
      'filePort': filePort,
      'reply': false,
      'time': DateTime.now().toIso8601String(),
    };

    final bytes = utf8.encode(jsonEncode(packet));

    _socket?.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);

    final subnetBroadcast = _guessSubnetBroadcast(localIp);
    if (subnetBroadcast != null) {
      _socket?.send(bytes, InternetAddress(subnetBroadcast), discoveryPort);
    }
  }

  Future<void> _sendPresenceTo(
    InternetAddress address, {
    required bool reply,
  }) async {
    final localIp = await _findLocalIpv4();
    if (localIp == null) return;

    final packet = {
      'type': 'presence',
      'id': selfId,
      'name': selfName,
      'ip': localIp,
      'textPort': textPort,
      'filePort': filePort,
      'reply': reply,
      'time': DateTime.now().toIso8601String(),
    };

    final bytes = utf8.encode(jsonEncode(packet));
    _socket?.send(bytes, address, discoveryPort);
  }

  String? _guessSubnetBroadcast(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }

  Future<String?> _findLocalIpv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (!ip.startsWith('127.')) {
            return ip;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _cleanupOfflineDevices() async {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _devices.entries) {
      if (entry.value.isManual) continue;

      final diff = now.difference(entry.value.lastSeen).inSeconds;
      if (diff > 10) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      final device = _devices.remove(key);
      if (device != null) {
        await LogService.instance.warn(
          'Device offline: ${device.name} (${device.ip})',
        );
      }
    }

    _emitDevices();
  }

  void updateDeviceSelection(String deviceId, bool selected) {
    final old = _devices[deviceId];
    if (old == null) return;

    _devices[deviceId] = old.copyWith(selected: selected);
    _emitDevices();
  }

  void addManualDevice({
    required String name,
    required String ip,
    required int textPort,
    required int filePort,
  }) {
    final id = 'manual-$ip-$textPort-$filePort';
    final old = _devices[id];

    _devices[id] = Device(
      id: id,
      name: name,
      ip: ip,
      textPort: textPort,
      filePort: filePort,
      isManual: true,
      selected: old?.selected ?? false,
      online: true,
      lastSeen: DateTime.now(),
    );

    _emitDevices();
    LogService.instance.info(
      'Manual device added: $name ($ip, text=$textPort, file=$filePort)',
    );
  }

  void rememberPeer({
    required String name,
    required String ip,
    required int textPort,
    required int filePort,
  }) {
    String? matchedKey;

    for (final entry in _devices.entries) {
      if (entry.value.ip == ip) {
        matchedKey = entry.key;
        break;
      }
    }

    final key = matchedKey ?? 'peer-$ip-$textPort-$filePort';
    final old = _devices[key];

    _devices[key] = Device(
      id: key,
      name: name,
      ip: ip,
      textPort: textPort,
      filePort: filePort,
      isManual: old?.isManual ?? true,
      selected: old?.selected ?? false,
      online: true,
      lastSeen: DateTime.now(),
    );

    _emitDevices();
  }

  void removeDevice(String deviceId) {
    final removed = _devices.remove(deviceId);
    if (removed != null) {
      _emitDevices();
      LogService.instance.warn(
        'Device removed: ${removed.name} (${removed.ip})',
      );
    }
  }

  List<Device> currentDevices() {
    final list = _devices.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _emitDevices() {
    _devicesController.add(currentDevices());
  }

  Future<void> dispose() async {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    await _devicesController.close();
  }
}
