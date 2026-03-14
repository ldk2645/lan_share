class TransferTask {
  final String id;
  final String title;
  final List<String> targetDeviceNames;
  double progress;
  String status;

  TransferTask({
    required this.id,
    required this.title,
    required this.targetDeviceNames,
    this.progress = 0,
    this.status = 'Waiting',
  });
}