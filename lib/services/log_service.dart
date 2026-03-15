import 'dart:async';
import 'dart:io';

class LogService {
  LogService._internal();

  static final LogService instance = LogService._internal();

  final List<String> _logs = <String>[];
  final StreamController<List<String>> _logStreamController =
      StreamController<List<String>>.broadcast();

  File? _logFile;
  bool _ready = false;

  Stream<List<String>> get logsStream => _logStreamController.stream;

  List<String> get currentLogs => List<String>.unmodifiable(_logs);

  String get allLogsText => _logs.join('\n');

  Future<void> init() async {
    if (_ready) return;

    final logDir = Directory(
      '${Directory.current.path}${Platform.pathSeparator}logs',
    );

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final now = DateTime.now();
    final fileName =
        'lan_share_'
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.log';

    _logFile = File('${logDir.path}${Platform.pathSeparator}$fileName');

    if (!await _logFile!.exists()) {
      await _logFile!.create(recursive: true);
    }

    _ready = true;
    await info('Log service started');
  }

  Future<void> info(String message) async {
    await _write('INFO', message);
  }

  Future<void> warn(String message) async {
    await _write('WARN', message);
  }

  Future<void> error(String message) async {
    await _write('ERROR', message);
  }

  Future<String> exportLogs() async {
    final exportDir = Directory(
      '${Directory.current.path}${Platform.pathSeparator}logs',
    );

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final now = DateTime.now();
    final fileName =
        'lan_share_export_'
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}.txt';

    final file = File('${exportDir.path}${Platform.pathSeparator}$fileName');

    await file.writeAsString(allLogsText, flush: true);
    return file.path;
  }

  Future<void> clear() async {
    _logs.clear();
    _logStreamController.add(List<String>.unmodifiable(_logs));
    await info('Logs cleared');
  }

  Future<void> _write(String level, String message) async {
    final now = DateTime.now();
    final line = '[${_formatTime(now)}] [$level] $message';

    _logs.add(line);

    if (_logs.length > 5000) {
      _logs.removeAt(0);
    }

    _logStreamController.add(List<String>.unmodifiable(_logs));

    if (_logFile != null) {
      await _logFile!.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    }
  }

  String _formatTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  Future<void> dispose() async {
    await _logStreamController.close();
  }
}
