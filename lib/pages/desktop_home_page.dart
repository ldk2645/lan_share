import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/device.dart';
import '../models/transfer_task.dart';
import '../services/connectivity_test_service.dart';
import '../services/discovery_service.dart';
import '../services/file_transfer_service.dart';
import '../services/log_service.dart';
import '../services/message_service.dart';
import '../services/save_location_service.dart';
import '../widgets/connectivity_test_box.dart';
import '../widgets/device_list.dart';
import '../widgets/drop_panel.dart';
import '../widgets/log_panel.dart';
import '../widgets/manual_device_box.dart';
import '../widgets/text_send_box.dart';
import '../widgets/transfer_queue.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  final TextEditingController _textController = TextEditingController();

  late final DiscoveryService _discoveryService;
  late final MessageService _messageService;
  late final FileTransferService _fileTransferService;

  StreamSubscription<List<Device>>? _deviceSub;
  StreamSubscription<List<String>>? _logSub;
  StreamSubscription<ReceivedTextMessage>? _messageSub;
  StreamSubscription<ReceivedFileRecord>? _fileSub;
  StreamSubscription<ReceivedFolderRecord>? _folderSub;

  List<Device> _devices = <Device>[];
  final List<TransferTask> _tasks = <TransferTask>[];
  List<String> _logs = <String>[];
  List<ReceivedTextMessage> _receivedMessages = <ReceivedTextMessage>[];
  List<ReceivedFileRecord> _receivedFiles = <ReceivedFileRecord>[];
  List<ReceivedFolderRecord> _receivedFolders = <ReceivedFolderRecord>[];

  String _localIp = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await LogService.instance.init();

    final ip = await _findBestLocalIpv4();
    if (mounted) {
      setState(() {
        _localIp = ip;
      });
    }

    _discoveryService = DiscoveryService(
      selfId: _buildSelfId(),
      selfName: _buildDesktopName(),
    );

    _messageService = MessageService(selfName: _buildDesktopName());

    _fileTransferService = FileTransferService(selfName: _buildDesktopName());

    _deviceSub = _discoveryService.devicesStream.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
      });
    });

    _logSub = LogService.instance.logsStream.listen((logs) {
      if (!mounted) return;
      setState(() {
        _logs = logs;
      });
    });

    _messageSub = _messageService.messageStream.listen((message) {
      _discoveryService.rememberPeer(
        name: message.fromDeviceName,
        ip: message.fromIp,
        textPort: message.fromTextPort,
        filePort: message.fromFilePort,
      );

      if (!mounted) return;
      setState(() {
        _receivedMessages = <ReceivedTextMessage>[
          message,
          ..._receivedMessages,
        ];
      });
    });

    _fileSub = _fileTransferService.receivedFileStream.listen((file) {
      _discoveryService.rememberPeer(
        name: file.fromDeviceName,
        ip: file.fromIp,
        textPort: file.fromTextPort,
        filePort: file.fromFilePort,
      );

      if (!mounted) return;
      setState(() {
        _receivedFiles = <ReceivedFileRecord>[file, ..._receivedFiles];
      });
    });

    _folderSub = _fileTransferService.receivedFolderStream.listen((folder) {
      _discoveryService.rememberPeer(
        name: folder.fromDeviceName,
        ip: folder.fromIp,
        textPort: folder.fromTextPort,
        filePort: folder.fromFilePort,
      );

      if (!mounted) return;
      setState(() {
        _receivedFolders = <ReceivedFolderRecord>[folder, ..._receivedFolders];
      });
    });

    if (mounted) {
      setState(() {
        _logs = LogService.instance.currentLogs;
      });
    }

    await _messageService.start();
    await _fileTransferService.startReceiver();
    await _discoveryService.start();
  }

  Future<String> _findBestLocalIpv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? fallback;

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();

        final looksVirtual =
            name.contains('virtual') ||
            name.contains('vmware') ||
            name.contains('vbox') ||
            name.contains('hyper-v') ||
            name.contains('vethernet') ||
            name.contains('vpn') ||
            name.contains('loopback') ||
            name.contains('bluetooth');

        for (final addr in interface.addresses) {
          final ip = addr.address;

          if (ip.startsWith('127.') || ip.startsWith('169.254.')) {
            continue;
          }

          fallback ??= ip;

          final isPrivateLan =
              ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              _is172Private(ip);

          if (isPrivateLan && !looksVirtual) {
            return ip;
          }
        }
      }

      return fallback ?? '0.0.0.0';
    } catch (_) {
      return '0.0.0.0';
    }
  }

  bool _is172Private(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    if (parts[0] != '172') return false;
    final second = int.tryParse(parts[1]) ?? -1;
    return second >= 16 && second <= 31;
  }

  String _buildSelfId() {
    return 'desktop-${Platform.localHostname}-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _buildDesktopName() {
    final name = Platform.localHostname.trim();
    if (name.isEmpty) {
      if (Platform.isLinux) {
        return 'Linux Device';
      }
      if (Platform.isMacOS) {
        return 'macOS Device';
      }
      return 'Windows Device';
    }
    return name;
  }

  @override
  void dispose() {
    _textController.dispose();
    _deviceSub?.cancel();
    _logSub?.cancel();
    _messageSub?.cancel();
    _fileSub?.cancel();
    _folderSub?.cancel();
    _discoveryService.dispose();
    _messageService.dispose();
    _fileTransferService.dispose();
    super.dispose();
  }

  void _toggleDevice(int index) {
    final device = _devices[index];
    _discoveryService.updateDeviceSelection(device.id, !device.selected);
  }

  void _addManualDevice(String name, String ip, int textPort, int filePort) {
    _discoveryService.addManualDevice(
      name: name,
      ip: ip,
      textPort: textPort,
      filePort: filePort,
    );
    _showMessage('Manual device added');
  }

  void _removeDevice(String deviceId) {
    _discoveryService.removeDevice(deviceId);
    _showMessage('Device removed');
  }

  List<Device> _selectedDevices() {
    return _devices.where((device) => device.selected).toList();
  }

  Device? _findDeviceByIp(String host) {
    for (final device in _devices) {
      if (device.ip == host) {
        return device;
      }
    }
    return null;
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    final selectedDevices = _selectedDevices();

    if (text.trim().isEmpty || selectedDevices.isEmpty) {
      _showMessage('Please input text and select at least one device');
      await LogService.instance.warn(
        'Send text blocked: empty text or no selected device',
      );
      return;
    }

    await _messageService.sendTextToDevices(
      text: text,
      fromName: _buildDesktopName(),
      fromIp: _localIp,
      devices: selectedDevices,
      contentType: 'text/plain',
      preserveFormat: true,
    );

    setState(() {
      _tasks.insert(
        0,
        TransferTask(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Text (${text.length} chars)',
          targetDeviceNames: selectedDevices.map((e) => e.name).toList(),
          progress: 1,
          status: 'Sent',
        ),
      );
    });

    _textController.clear();
    _showMessage('Text sent');
  }

  Future<void> _pickAndSendFile() async {
    final selectedDevices = _selectedDevices();

    if (selectedDevices.isEmpty) {
      _showMessage('Please select at least one device');
      await LogService.instance.warn('Send file blocked: no device selected');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      withReadStream: false,
      lockParentWindow: true,
    );

    if (result == null || result.files.isEmpty) {
      await LogService.instance.warn('File pick canceled by user');
      return;
    }

    final files = <File>[];
    for (final picked in result.files) {
      final path = picked.path;
      if (path == null || path.isEmpty) {
        continue;
      }
      files.add(File(path));
    }

    if (files.isEmpty) {
      _showMessage('Cannot read picked file path');
      await LogService.instance.error('All picked file paths are empty');
      return;
    }

    int totalBytes = 0;
    for (final file in files) {
      totalBytes += await file.length();
    }

    final task = TransferTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: files.length == 1
          ? files.first.uri.pathSegments.last
          : '${files.length} files',
      targetDeviceNames: selectedDevices.map((e) => e.name).toList(),
      progress: 0.1,
      status: files.length == 1 ? 'Sending file...' : 'Sending files...',
    );

    setState(() {
      _tasks.insert(0, task);
    });

    await _fileTransferService.sendFilesToDevices(
      files: files,
      fromName: _buildDesktopName(),
      fromIp: _localIp,
      devices: selectedDevices,
    );

    setState(() {
      task.progress = 1;
      task.status =
          '${files.length} file(s) sent (${totalBytes} bytes)';
    });

    _showMessage(
      files.length == 1 ? 'File sent' : '${files.length} files sent',
    );
  }

  Future<void> _pickAndSendFolder() async {
    final selectedDevices = _selectedDevices();

    if (selectedDevices.isEmpty) {
      _showMessage('Please select at least one device');
      await LogService.instance.warn('Send folder blocked: no device selected');
      return;
    }

    final folderPath = await FilePicker.platform.getDirectoryPath(
      lockParentWindow: true,
    );

    if (folderPath == null || folderPath.trim().isEmpty) {
      await LogService.instance.warn('Folder pick canceled by user');
      return;
    }

    final folder = Directory(folderPath);
    final folderName = folder.uri.pathSegments.where((e) => e.isNotEmpty).last;

    final task = TransferTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '$folderName/',
      targetDeviceNames: selectedDevices.map((e) => e.name).toList(),
      progress: 0.1,
      status: 'Sending folder...',
    );

    setState(() {
      _tasks.insert(0, task);
    });

    await _fileTransferService.sendFolderToDevices(
      folder: folder,
      fromName: _buildDesktopName(),
      fromIp: _localIp,
      devices: selectedDevices,
    );

    setState(() {
      task.progress = 1;
      task.status = 'Folder sent';
    });

    _showMessage('Folder sent');
  }

  Future<void> _copyAllLogs() async {
    final text = LogService.instance.allLogsText;
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('Logs copied');
  }

  Future<void> _saveLogs() async {
    final path = await LogService.instance.exportLogs();
    await LogService.instance.info('Logs exported to $path');
    _showMessage('Logs saved: $path');
  }

  Future<void> _testConnection(String host) async {
    await LogService.instance.info('Start connection test to $host');

    final matched = _findDeviceByIp(host);
    final textPort = matched?.textPort ?? 40402;
    final filePort = matched?.filePort ?? 40403;

    final textResult = await ConnectivityTestService.testPort(
      host: host,
      port: textPort,
    );

    if (textResult.success) {
      await LogService.instance.info(
        'Text port test success: ${textResult.host}:${textResult.port}',
      );
    } else {
      await LogService.instance.error(
        'Text port test failed: ${textResult.host}:${textResult.port} -> ${textResult.message}',
      );
    }

    final fileResult = await ConnectivityTestService.testPort(
      host: host,
      port: filePort,
    );

    if (fileResult.success) {
      await LogService.instance.info(
        'File port test success: ${fileResult.host}:${fileResult.port}',
      );
    } else {
      await LogService.instance.error(
        'File port test failed: ${fileResult.host}:${fileResult.port} -> ${fileResult.message}',
      );
    }

    _showMessage('Connection test finished');
  }

  Future<void> _selfTest() async {
    await LogService.instance.info('Start self test to 127.0.0.1');
    await _testConnection('127.0.0.1');
  }

  Future<void> _copyReceivedText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('Text copied');
  }

  Future<void> _saveReceivedText(ReceivedTextMessage msg) async {
    final dir = await SaveLocationService.instance
        .ensureSenderCategoryDirectory(
          senderName: msg.fromDeviceName,
          category: 'Text',
        );

    final fileName =
        'text_${msg.time.year.toString().padLeft(4, '0')}-'
        '${msg.time.month.toString().padLeft(2, '0')}-'
        '${msg.time.day.toString().padLeft(2, '0')}_'
        '${msg.time.hour.toString().padLeft(2, '0')}-'
        '${msg.time.minute.toString().padLeft(2, '0')}-'
        '${msg.time.second.toString().padLeft(2, '0')}.txt';

    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(msg.text, flush: true);

    await LogService.instance.info('Received text saved to ${file.path}');
    _showMessage('Text saved: ${file.path}');
  }

  Future<void> _editReceivedText(ReceivedTextMessage msg) async {
    final controller = TextEditingController(text: msg.text);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: 760,
            height: 560,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit / Save Text',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: controller.text),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edited text copied')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final dir = await SaveLocationService.instance
                            .ensureSenderCategoryDirectory(
                              senderName: msg.fromDeviceName,
                              category: 'Text',
                            );

                        final now = DateTime.now();
                        final fileName =
                            'edited_text_'
                            '${now.year.toString().padLeft(4, '0')}-'
                            '${now.month.toString().padLeft(2, '0')}-'
                            '${now.day.toString().padLeft(2, '0')}_'
                            '${now.hour.toString().padLeft(2, '0')}-'
                            '${now.minute.toString().padLeft(2, '0')}-'
                            '${now.second.toString().padLeft(2, '0')}.txt';

                        final file = File(
                          '${dir.path}${Platform.pathSeparator}$fileName',
                        );

                        await file.writeAsString(controller.text, flush: true);

                        await LogService.instance.info(
                          'Edited text saved to ${file.path}',
                        );

                        if (!mounted) return;
                        Navigator.of(context).pop();
                        _showMessage('Edited text saved: ${file.path}');
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _chooseSaveBasePath() async {
    await SaveLocationService.instance.chooseCustomBasePath();
    if (!mounted) return;
    setState(() {});
    _showMessage('Custom save path selected');
  }

  void _useDefaultSavePath() {
    SaveLocationService.instance.useDefault();
    setState(() {});
    _showMessage('Switched to default save path');
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.devices_other,
              color: Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lan Share',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Device: ${_buildDesktopName()}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  'IP: $_localIp   Text: 40402   File: 40403   Online: ${_devices.length}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavePathCard() {
    final isDefault = SaveLocationService.instance.useDefaultPath;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Save Path',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isDefault ? 'Mode: Default Path' : 'Mode: Custom Path',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          FutureBuilder<String>(
            future: SaveLocationService.instance.previewBaseReceivePath(),
            builder: (context, snapshot) {
              final shownPath = snapshot.data ?? 'Loading...';
              return SelectableText(
                shownPath,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _useDefaultSavePath,
                child: const Text('Use Default'),
              ),
              ElevatedButton(
                onPressed: _chooseSaveBasePath,
                child: const Text('Choose Custom Folder'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedTextPage() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Received Text',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_receivedMessages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No text received yet')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _receivedMessages.length,
              itemBuilder: (context, index) {
                final msg = _receivedMessages[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.fromDeviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${msg.fromIp} | ${msg.contentType}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: SelectableText(
                            msg.text,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _copyReceivedText(msg.text),
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _editReceivedText(msg),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _saveReceivedText(msg),
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFolderChildren(String folderPath) {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      return <Widget>[
        const ListTile(
          dense: true,
          title: Text(
            'Folder does not exist',
            style: TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ),
      ];
    }

    final entities = dir.listSync(recursive: true);

    if (entities.isEmpty) {
      return <Widget>[
        const ListTile(
          dense: true,
          title: Text(
            'Empty folder',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ];
    }

    return entities.map((entity) {
      final isFile = entity is File;
      final name = entity.path.replaceAll('\\', '/').split('/').last;
      return ListTile(
        dense: true,
        leading: Icon(
          isFile ? Icons.insert_drive_file : Icons.folder,
          size: 16,
          color: const Color(0xFF2563EB),
        ),
        title: Text(name, style: const TextStyle(fontSize: 12)),
      );
    }).toList();
  }

  Widget _buildReceivedStoragePage() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Received Files / Folders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_receivedFiles.isEmpty && _receivedFolders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No file or folder received yet')),
            )
          else ...[
            if (_receivedFolders.isNotEmpty) ...[
              const Text(
                'Folders',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._receivedFolders.map((folder) {
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: ExpansionTile(
                    leading: const Icon(Icons.folder, color: Color(0xFF2563EB)),
                    title: Text(folder.folderName),
                    subtitle: SelectableText(
                      'From: ${folder.fromDeviceName} (${folder.fromIp})\nSaved: ${folder.savedPath}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    children: _buildFolderChildren(folder.savedPath),
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],
            if (_receivedFiles.isNotEmpty) ...[
              const Text(
                'Files',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._receivedFiles.map((file) {
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.insert_drive_file,
                      color: Color(0xFF2563EB),
                    ),
                    title: Text(file.fileName),
                    subtitle: SelectableText(
                      'From: ${file.fromDeviceName} (${file.fromIp})\n'
                      'Size: ${file.size} bytes\n'
                      'Saved: ${file.savedPath}',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSendPage() {
    final defaultHost = _devices.isNotEmpty ? _devices.first.ip : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1200;

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _buildCard(
                      child: TextSendBox(
                        controller: _textController,
                        onSend: _sendText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: DropPanel(
                        onPickFile: _pickAndSendFile,
                        onPickFolder: _pickAndSendFolder,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(child: TransferQueue(tasks: _tasks)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildCard(
                      child: DeviceList(
                        devices: _devices,
                        onToggle: _toggleDevice,
                        onRemove: _removeDevice,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: ManualDeviceBox(onAddDevice: _addManualDevice),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: ConnectivityTestBox(
                        defaultHost: defaultHost,
                        onTest: _testConnection,
                        onSelfTest: _selfTest,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSavePathCard(),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildCard(
              child: DeviceList(
                devices: _devices,
                onToggle: _toggleDevice,
                onRemove: _removeDevice,
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(child: ManualDeviceBox(onAddDevice: _addManualDevice)),
            const SizedBox(height: 12),
            _buildCard(
              child: ConnectivityTestBox(
                defaultHost: defaultHost,
                onTest: _testConnection,
                onSelfTest: _selfTest,
              ),
            ),
            const SizedBox(height: 12),
            _buildSavePathCard(),
            const SizedBox(height: 12),
            _buildCard(
              child: TextSendBox(
                controller: _textController,
                onSend: _sendText,
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(
              child: DropPanel(
                onPickFile: _pickAndSendFile,
                onPickFolder: _pickAndSendFolder,
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(child: TransferQueue(tasks: _tasks)),
          ],
        );
      },
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: _buildHeaderCard(),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const TabBar(
                  tabs: [
                    Tab(text: 'Send'),
                    Tab(text: 'Received Text'),
                    Tab(text: 'Received Files'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          _buildSendPage(),
                          const SizedBox(height: 14),
                          _buildCard(
                            child: SizedBox(
                              height: 220,
                              child: LogPanel(
                                logs: _logs,
                                onCopyAll: _copyAllLogs,
                                onSaveLogs: _saveLogs,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _buildReceivedTextPage(),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _buildReceivedStoragePage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
