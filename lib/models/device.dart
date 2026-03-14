class Device {
  final String id;
  final String name;
  final String ip;
  final int textPort;
  final int filePort;
  final bool isManual;
  bool selected;
  bool online;
  DateTime lastSeen;

  Device({
    required this.id,
    required this.name,
    required this.ip,
    required this.textPort,
    required this.filePort,
    this.isManual = false,
    this.selected = false,
    this.online = true,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Device copyWith({
    String? id,
    String? name,
    String? ip,
    int? textPort,
    int? filePort,
    bool? isManual,
    bool? selected,
    bool? online,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      textPort: textPort ?? this.textPort,
      filePort: filePort ?? this.filePort,
      isManual: isManual ?? this.isManual,
      selected: selected ?? this.selected,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
