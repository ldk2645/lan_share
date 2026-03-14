class ReceivedFileMessage {
  final String fromDeviceName;
  final String fromIp;
  final String fileName;
  final String savedPath;
  final int fileSize;
  final DateTime time;

  ReceivedFileMessage({
    required this.fromDeviceName,
    required this.fromIp,
    required this.fileName,
    required this.savedPath,
    required this.fileSize,
    required this.time,
  });
}
